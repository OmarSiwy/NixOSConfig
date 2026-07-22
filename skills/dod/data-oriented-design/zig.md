# Zig 0.16.0 — realizing the principles

Companion to foundations.md. Target compiler: **0.16.0** (shipped 2026-04-14;
the release that made I/O an interface and standardized the "unmanaged" containers).
Each section maps a principle from the theory document to Zig mechanics, then the last
two sections cover the language's intended handling of optionals and errors.

A note on 0.16 container init used throughout: unmanaged containers (ArrayList,
MultiArrayList, etc.) are initialized from the `.empty` constant and take the allocator
as a parameter to each method. The old `.{}` default-literal init for `ArrayList` was
removed. (For less-common containers, confirm the empty constant against std for your
build.)

---

## 1. Data-Oriented Design in Zig

Zig is, in practice, the reference language for DOD: the techniques in Kelley's talk
were developed _on the Zig compiler_, and several of them are first-class in the std
library.

### Struct-of-Arrays: `std.MultiArrayList`

This is the native realization of "eliminate padding with SoA." It stores the fields of
a struct as separate arrays but presents a list-like API.

```zig
const Particle = struct { pos: [3]f32, vel: [3]f32, color: u32, alive: bool };

var ps: std.MultiArrayList(Particle) = .empty;
defer ps.deinit(allocator);
try ps.append(allocator, .{ .pos = .{0,0,0}, .vel = .{1,0,0}, .color = 0, .alive = true });

// A pass that only needs pos and vel gets two contiguous column slices —
// no color/alive bytes dragged into cache, autovectorizable:
const positions = ps.items(.pos);   // [][3]f32
const vels      = ps.items(.vel);   // [][3]f32
for (positions, vels) |*p, v| { p[0] += v[0]; p[1] += v[1]; p[2] += v[2]; }
```

`MultiArrayList` also reorders fields internally to minimize padding, so even the
footprint is smaller than the equivalent `[]Particle`. Use it when passes are
column-wise; keep a plain `[]Particle` (AoS) when every pass touches whole elements.

### Indices instead of pointers

A pointer is 8 bytes and pins the backing storage. An index is usually a `u32` and lets
you grow/relocate the arena freely. Make the index a distinct type so it can't be
confused with an ordinary integer:

```zig
const NodeIndex = enum(u32) { _ };          // a u32 you can't accidentally do math on
const Node = struct { first_child: NodeIndex, next_sibling: NodeIndex, tag: Tag };
var nodes: std.MultiArrayList(Node) = .empty;
// "pointer" to a node is now `NodeIndex`; the tree is positions in `nodes`.
```

### Booleans / cold fields out of band

Don't pay padding for a rare flag inside a hot struct. Keep hot fields in the main
array; move rare data to a side structure keyed by the same index (e.g. a small
`std.AutoHashMapUnmanaged(NodeIndex, Diagnostics)` consulted only on the cold path).

### Encodings instead of polymorphism: tagged unions + packed fields

```zig
const Shape = union(enum) { circle: f32, rect: struct { w: f32, h: f32 } };
// Branch on the tag at the top of a loop, or bucket elements by tag so each
// inner loop is monomorphic. No vtable, no per-element indirect call.
```

Zig's arbitrary-width integers and `packed struct` let you shrink elements to the bit:

```zig
const Cell = packed struct(u8) { kind: u3, flags: u3, dirty: bool, visited: bool };
// Exactly one byte. More elements per cache line, often free vectorization.
```

### Compile-time maps and enum tables (no runtime hashing for static data)

```zig
const keywords = std.StaticStringMap(Token).initComptime(.{
    .{ "fn", .kw_fn }, .{ "const", .kw_const }, .{ "return", .kw_return },
});
// Built at compile time — the Zig analogue of a perfect-hash table.

const counts = std.enums.EnumArray(Color, u32).initFill(0); // dense array keyed by enum
```

---

## 2. Negative-overhead abstraction in Zig

Zig's stance is _no hidden cost_: there is no hidden control flow, no hidden allocation,
and no hidden function calls. Abstraction happens at **compile time**, so it leaves no
runtime residue.

### `comptime` generics monomorphize — the abstraction vanishes

```zig
fn Vec(comptime n: usize, comptime T: type) type {
    return struct {
        e: [n]T,
        fn dot(a: @This(), b: @This()) T {
            var acc: T = 0;
            inline for (0..n) |i| acc += a.e[i] * b.e[i]; // unrolled at compile time
            return acc;
        }
    };
}
// Vec(3, f32) is a fully specialized type. The generality exists only in the compiler;
// the emitted code is what you'd hand-write for a 3-float dot product.
```

Because types are comptime values, generic data structures cost nothing at runtime —
this is the same "zero-cost" property as Rust's monomorphization, reached via `comptime`
rather than a separate generics system.

### What this buys you, and the discipline

A clean, generic, well-named transformation in Zig compiles to the same instructions as
the inlined hand-written loop, because the abstraction is resolved before codegen. The
discipline from the theory doc still applies: when a loop is hot, check the result —
`zig build-obj -O ReleaseFast --verbose` / a disassembler / godbolt — rather than
assuming the unrolling and vectorization happened.

---

## 3. API design in Zig (Muratori's rules, language-enforced)

Several of Muratori's rules are _defaults_ in idiomatic Zig:

- **Caller owns memory (low coupling / optional resource management).** Functions that
  allocate take an `Allocator` parameter; the caller decides arena vs. page vs. fixed
  buffer. You literally cannot smuggle a hidden global allocation into idiomatic code.
- **Transparent data.** Plain `struct`s with public fields are the norm; expose them
  unless there's an invariant. This keeps data inspectable, serializable, and
  SoA-able — Muratori's "transparent unless a reason to be opaque."
- **Granularity.** Offer the fine-grained primitive and a convenience wrapper built on
  it. Example shape: `parseAlloc(io, allocator, bytes)` (convenience) implemented on top
  of `parse(io, scratch, bytes, out)` (caller owns `out` and scratch).
- **Error sets are part of the API.** A function's error set (below) is a precise,
  checked contract of how it can fail — surface a named set rather than a catch-all when
  callers need to discriminate.

### I/O is an interface — pass `Io`, like you pass `Allocator` (0.16)

Anything that performs I/O, blocks, or introduces nondeterminism takes an `Io`. There is
no global I/O and no function coloring; you choose threaded vs. evented backends at the
top via "Juicy Main":

```zig
pub fn main(init: std.process.Init) !void {
    const io = init.io;           // pass `io` down to anything doing I/O
    // args come from `init`, not a global `std.os.argv` (which was removed)
}
```

`GenericReader`/`AnyReader`/`FixedBufferStream` were removed; use `std.Io.Reader` /
`std.Io.Writer` (a fixed buffer writer is `std.Io.Writer.fixed(buf)`; a file's
reader/writer is reached via `file.reader(&buf).interface`).

### `std.ArrayList` in 0.16

The default `std.ArrayList(T)` _is_ the unmanaged container (no stored allocator). Use
it directly — not `std.ArrayListUnmanaged` (legacy) nor the `Managed` wrapper:

```zig
var list: std.ArrayList(u8) = .empty;
defer list.deinit(allocator);
try list.append(allocator, x);     // allocator passed per call
```

---

## 4. Optionals — "absence is a normal, expected outcome"

Zig draws a hard line between _absence_ (optional) and _failure_ (error). Use an
optional `?T` when "nothing" is an ordinary, expected result — a lookup miss, an
end-of-iteration, a not-yet-set field. Absence is **not** an error and should not be
modeled as one.

```zig
fn find(haystack: []const u8, needle: u8) ?usize {
    for (haystack, 0..) |c, i| if (c == needle) return i;
    return null;                 // expected, ordinary "not found"
}
```

Idiomatic consumption:

```zig
// Unwrap-or-default:
const i = find(s, '/') orelse s.len;

// Capture if present (the standard form — no null deref possible):
if (find(s, '/')) |idx| { useIt(idx); } else { noSlash(); }

// Iterators return optionals; the loop ends when it yields null:
while (it.next()) |item| { process(item); }

// Assert-present (panics in safe builds if null) — use only when truly impossible:
const v = maybe.?;
```

Guidance: prefer `orelse` and `if (opt) |v|` capture; reserve `.?` for cases the
surrounding logic has already guaranteed. Don't reach for an error union to express
"not found."

---

## 5. Error handling — "something went wrong," as a checked value

Failures are values, via **error sets** and **error unions**. An error set is a set of
named error values; an error union `E!T` is "either an `E` or a `T`."

```zig
const ParseError = error{ Unexpected, Overflow };

// `!T` infers the error set from the body; name the set when callers must discriminate.
fn parseU32(bytes: []const u8) ParseError!u32 {
    var acc: u32 = 0;
    for (bytes) |c| {
        if (c < '0' or c > '9') return error.Unexpected;
        acc = std.math.mul(u32, acc, 10) catch return error.Overflow;
        acc += c - '0';
    }
    return acc;
}
```

Propagation and handling:

```zig
// `try` = "evaluate, and if it's an error, return it from the current function":
const n = try parseU32(field);

// `catch` = handle locally, optionally with the error captured:
const n2 = parseU32(field) catch 0;                 // substitute a default
const n3 = parseU32(field) catch |err| switch (err) {
    error.Overflow => return reportTooBig(),
    error.Unexpected => return reportBadChar(),
};
```

Cleanup on the _error_ path only — the counterpart to `defer`:

```zig
const buf = try allocator.alloc(u8, n);
errdefer allocator.free(buf);       // freed only if a later `try` in this fn fails
try fillOrFail(buf);                // on failure, errdefer runs; on success it doesn't
return buf;                         // success: caller owns `buf`
```

### Combining the two

`!?T` is a function that can _fail_ (error union) and, when it succeeds, may legitimately
return _nothing_ (optional): e.g. `fn next(self: *It) !?Token` — reading can error, and
a successful read can be end-of-stream (`null`). This is the precise, idiomatic way to
say both things at once.

### Conventions

- Optional for expected absence; error union for genuine failure. Never use an error to
  signal an ordinary "not found."
- `try` to propagate, `catch` to handle, `errdefer` to unwind partial work.
- Don't discard errors silently. If a failure is truly impossible, make that explicit
  (`catch unreachable`) rather than swallowing it.
- A function's error set is part of its contract — keep it as narrow and named as the
  callers need.

---

## 6. Memory and allocation in Zig

Zig is the reference implementation of "allocator as an explicit dependency": every
allocating function takes an `Allocator`, so the caller chooses the strategy and the
hot-path discipline from the theory doc is enforced by the language rather than left to
convention.

The 0.16 "Juicy Main" `Init` struct hands you two allocators for free, so you rarely
construct one by hand in `main`:

```zig
pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;        // default general-purpose alloc; leak-checked in debug
    const arena = init.arena;    // permanent, thread-safe arena, cleaned up on exit
    const io = init.io;
}
```

The strategies, mapped to std:

```zig
// General-purpose with leak detection. (GeneralPurposeAllocator is a deprecated alias.)
var gpa: std.heap.DebugAllocator(.{}) = .init;
defer _ = gpa.deinit();             // reports leaks
const a = gpa.allocator();

// Arena: allocate freely, free all at once when the phase ends. 0.16: thread-safe & lock-free.
var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
defer arena.deinit();               // frees everything; individual free() is a no-op
const ra = arena.allocator();       // perfect for per-request / per-frame work

// Fixed buffer: no heap at all. OutOfMemory when full; reset() to reuse.
var buf: [64 * 1024]u8 = undefined;
var fba = std.heap.FixedBufferAllocator.init(&buf);
const fa = fba.allocator();         // hot paths, embedded, bounded work
```

Other std options: `std.heap.page_allocator` (coarse, straight from the OS),
`std.heap.c_allocator` (malloc), and `std.heap.smp_allocator` (a fast multithreaded
general-purpose allocator intended for release builds — confirm availability for your
build). Tests use `std.testing.allocator`, which is a `DebugAllocator` with leak
detection.

Practice: pick an arena for anything with a clear phase lifetime; pre-size growable
containers (`ensureTotalCapacity`) before a loop instead of growing element-by-element;
and because the allocator is a parameter, you can swap strategies without touching the
code that uses the memory.

---

## 7. Concurrency in Zig (0.16, via `std.Io`)

`std.Thread.Pool` was removed in 0.16; concurrency lives in the `Io` interface, chosen
at the top like the allocator. Two primitives, with a crucial distinction:

- **`io.async(fn, args)` -> `Future(T)`** expresses _asynchrony_: the call is
  independent of surrounding logic. Creating it is infallible and portable, even on `Io`
  implementations with no real concurrency (it may run on the same thread).
- **`io.concurrent(...)`** expresses genuine _concurrency_: the tasks must make progress
  simultaneously (e.g. a producer and consumer that synchronize). It can fail with
  `error.ConcurrencyUnavailable` on a single-threaded backend.

```zig
// One independent task, awaited later:
var future = io.async(compute, .{input});
const result = future.await(io);

// A group of data-parallel tasks over disjoint chunks (partition, don't share):
var group: std.Io.Group = .init;
for (chunks) |chunk| try group.concurrent(io, processChunk, .{ io, chunk });
try group.await(io);
```

Backends: `std.Io.Threaded` is the usable one (a thread pool); `std.Io.Evented`
(io_uring on Linux, GCD on macOS) is experimental in 0.16 — prefer `Threaded` for
anything real. For raw threads and primitives, `std.Thread`, `std.Thread.Mutex`, and
`std.atomic.Value(T)` still exist. The async-vs-concurrent choice is the one to get
right: ask for `async` when you mean "I don't care when this runs," `concurrent` when
two tasks must run at once or they deadlock.

---

## 8. Type-driven design in Zig

Zig has no Rust-style typestate, but it gives you sharp tools to make illegal states
unrepresentable:

- **Tagged unions over tag-plus-untyped-payload.** `union(enum)` forces every `switch`
  to handle the active field, and you cannot read the wrong variant. This is the
  "encoding instead of polymorphism" technique _and_ the correctness technique at once.
- **Distinct index/ID types** via `enum(u32) { _ }` so an index can't be confused with
  an integer or subjected to arithmetic.
- **Narrowest representation**: `u3`, `enum(u8)`, `packed struct` — fewer bit patterns
  means fewer illegal states.
- **Optionals and error unions are this principle built into the language**: `?T` makes
  absence impossible to ignore (no null deref in safe code), and `E!T` makes failure
  impossible to ignore (the result must be handled or propagated).
- **Parse, don't validate**: have a parse function return a refined struct
  (`fn parse(bytes) !Config`), and let the rest of the program take `Config` by value —
  no re-checking downstream. Push as much as possible to `comptime` when the inputs are
  known at compile time.

---

## 9. SIMD in Zig: `@Vector`

Zig has portable SIMD as a language builtin — no crate, no nightly. `@Vector(n, T)`
participates in the normal operators lane-wise and compiles to the target's SIMD
instructions.

```zig
const V = @Vector(8, f32);

fn dot(a: []const f32, b: []const f32) f32 {
    var acc: V = @splat(0.0);
    var i: usize = 0;
    while (i + 8 <= a.len) : (i += 8) {
        const va: V = a[i..][0..8].*;     // load 8 contiguous lanes
        const vb: V = b[i..][0..8].*;
        acc += va * vb;                   // 8 multiply-adds, one instruction each
    }
    var sum = @reduce(.Add, acc);         // horizontal reduce
    while (i < a.len) : (i += 1) sum += a[i] * b[i];  // scalar remainder
    return sum;
}
```

`@reduce`, `@shuffle`, and `@select` cover horizontal reductions, lane permutation, and
branchless selection (use `@select` instead of an `if` inside the kernel). SoA layout —
`MultiArrayList(...).items(.field)` giving a contiguous `[]f32` — feeds `@Vector`
directly, which is the whole point of laying data out in columns. Process in chunks of
the vector width, handle the remainder scalar, keep the inner loop branch-free, and
check the disassembly to confirm the vector instructions emitted.
