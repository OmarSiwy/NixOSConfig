---
name: writing-leak-free-zig
description: "Ranked playbook for leak-free memory management in Zig 0.16 — prevent leaks by construction (runtime allocators, static allocation, arenas) before falling back to owned-memory discipline. Use when writing or reviewing Zig code that allocates; mentions allocator, alloc/free, defer/errdefer, arena, deinit, toOwnedSlice, DebugAllocator, std.process.Init, checkAllAllocationFailures, or memory leaks."
---

# Writing Leak-Free Zig (0.16)

Ranked playbook. Higher rung = leak prevented by construction, no analysis
needed. Only drop a rung when the one above doesn't fit the lifetime shape.
Everything here is 0.16-accurate and matches what the ecosystem converged on
(std runtime, Ghostty, TigerBeetle) and what makes code provable by static
analysis (VERIFIED under the zigleak discipline).

## Rung 0 — Take what the runtime gives you

```zig
pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator(); // process-lifetime, auto-freed at exit
    const gpa = init.gpa;                 // mode-selected; leak-checked in Debug
    ...
}
```

Since 0.16 the old hand-written mode-switch idiom is built into `start.zig`:
Debug gets a `DebugAllocator` with a leak report at exit; release gets
`c_allocator`/`smp_allocator`/`wasm_allocator`. Don't re-implement it.

Two caveats the runtime does NOT cover:

- The exit leak check is **soft** — prints, exits 0. CI won't fail.
- Leak checking exists only in Debug (and some ReleaseSafe configs). Release
  builds run **unwatched**.

Hard-fail version when you need a gate:

```zig
var dbg: std.heap.DebugAllocator(.{}) = .init; // .{ .safety = true } forces checks even in ReleaseFast
defer if (dbg.deinit() == .leak) @panic("leaked");
```

## Rung 1 — Don't allocate at runtime (TigerBeetle)

> "All memory must be statically allocated at startup. No memory may be
> dynamically allocated (or freed and reallocated) after initialization."
> — TIGER_STYLE

Allocate all capacity at init from explicit limits; after that, no alloc, no
free, no leak — the phenomenon is deleted, not detected. Fits servers and
databases with known bounds. Forces capacity math upfront, which is a feature.

## Rung 2 — Arena per phase

When a batch of allocations dies together (request, frame, parse, test case):

```zig
var arena_state = std.heap.ArenaAllocator.init(gpa);
defer arena_state.deinit();          // one line frees everything
const arena = arena_state.allocator();
// allocate freely below; individual free() is a no-op
```

Per-item leaks structurally impossible inside the phase. The only failure mode
left: arena outliving its phase (unbounded growth in a long-running loop —
that's a lifetime-shape mismatch, go to Rung 3 for those objects).

## Rung 3 — Owned memory under the discipline

When lifetimes genuinely differ per object, follow rules that make ownership
locally checkable. These are exactly what static analysis can verify:

**One owner per allocation.** One name holds the free obligation. Don't keep
two live names for one region — if you copy the slice, the original is dead
to you.

**Pair at the alloc site, immediately.**

```zig
const buf = try gpa.alloc(u8, n);
defer gpa.free(buf);        // owner stays here
// — or —
errdefer gpa.free(buf);     // ownership will move (return / store) on success
```

Never "free later, somewhere below." The disposal line sits next to the
allocation line, always. (TigerBeetle codifies this visually: blank lines
group each alloc with its dealloc so review can pair them.)

**`errdefer` across every fallible gap.** The #1 real-world leak. Any owned
value alive across a `try` needs `errdefer` until ownership moves:

```zig
const a_buf = try gpa.alloc(u8, n);
errdefer gpa.free(a_buf);
const b_buf = try gpa.alloc(u8, m);  // if THIS fails, a_buf still freed
errdefer gpa.free(b_buf);
```

**Ownership transfer is explicit and named.** Returning owned memory: say so
(`/// Caller owns returned memory`), and follow std's verb conventions —
`dupe`, `toOwnedSlice`, `create` return ownership; `getPtr`, slices, views
don't. Free what you got FROM the same interface you got it from; never free
a sub-slice or a view.

**Free with the same allocator.** The allocator is part of the value's
identity. Store it in the struct or pass it to `deinit` — same convention std
uses (`list.deinit(gpa)`).

**No conditional ownership.** `if (cond) free(p)` means ownership depends on a
runtime value — unreviewable and unprovable. Restructure so each path has
unconditional obligations.

## Type rules

**deinit-complete or bust.** If any field can own memory, the type has a
`deinit`, and `deinit` disposes every owning field. Partial deinit is a leak
factory (one leak per instance).

```zig
const Bag = struct {
    data: []u8,
    names: std.ArrayList([]u8),

    pub fn deinit(self: *Bag, gpa: std.mem.Allocator) void {
        for (self.names.items) |n| gpa.free(n); // elements first
        self.names.deinit(gpa);                 // then container
        gpa.free(self.data);
    }
};
```

**Containers own two levels.** `deinit` frees the storage, not the elements.
If elements are owned, free them in a loop before `deinit` — the loop above
is the recognized idiom.

**Borrowed fields: mark them.** `[]const u8` can be an owned string or a
static literal — the type can't tell. If a field is a borrow, name it so
(`label_ref`, comment) and never free it; mixing owned and borrowed values in
one field is how double-frees happen.

## Test rules

**Every test allocates through `std.testing.allocator`.** Unconditionally
checking; a leaked byte fails the test. Non-negotiable baseline.

**Error paths get `checkAllAllocationFailures`.** Exhaustively fails each
allocation point in turn — the only way to actually execute your `errdefer`s:

```zig
test "no leak on any allocation failure" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, run, .{args});
}
```

**Fuzz what you can't enumerate** (`std.testing.fuzz`) — evidence, not proof;
absence of a report is not absence of a leak.

## Build-mode truths (know what watches you where)

| Build              | Default watcher            | Leaks caught?                |
| ------------------ | -------------------------- | ---------------------------- |
| `zig test`         | `std.testing.allocator`    | hard fail, per test          |
| Debug run          | runtime `DebugAllocator`   | printed at exit, exit code 0 |
| ReleaseSafe + libc | `c_allocator`              | none                         |
| ReleaseFast/Small  | `smp_allocator`/decomposed | none                         |

Safety mode ≠ leak checking. Production runs unwatched — whatever leaks there,
leaks. That's why the rungs are ranked construction-first: construction holds
in every mode; detection only where the detector is compiled in.

## Review conventions

- Group each allocation with its disposal (blank-line blocks) — pairs must be
  eyeball-able.
- Smallest possible scope for owning variables.
- A function that allocates > ~2 owned values wants an arena or a struct with
  a deinit — many parallel `errdefer`s is a smell.
- Unexplained `[]u8` in a struct is a question: owned or borrowed? Make the
  answer visible.

## One-page summary

1. Runtime gives you leak-checked Debug + arena for free — use `init.gpa` /
   `init.arena`, don't hand-roll.
2. Prefer not allocating; then arenas per phase; owned memory is the last
   resort, under single-owner + adjacent-disposal + `errdefer` rules.
3. Types with owning fields are deinit-complete, elements included.
4. Tests: `std.testing.allocator` always, `checkAllAllocationFailures` for
   error paths.
5. Nothing watches release builds. Discipline and construction are the only
   guarantees that ship.
