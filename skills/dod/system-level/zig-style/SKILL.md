---
name: zig-style
description: "Zig programming style rules. Zig has no nested method chaining, so operations are stacked as sequential statements grouped tightly. Related operations touch — unrelated operations get a blank line. Loaded by the system-level router when writing Zig code."
---

# Zig Programming Style

Applies after the [problem mapping](../shared/problem-mapping.md) and [pseudocode](../shared/pseudocode.md) steps are done. This skill governs **how** the Zig code reads, not what it does.

For DOD, memory, concurrency, and type design rules, load [../../Brogramming/principles/zig.md](../../Brogramming/principles/zig.md).

## Core rule: stacked operations

Zig does not support nested method chaining (no `.iter().map()...`). When you need to chain transformations, **stack them as sequential statements**. The visual grouping of statements IS the code's structure.

The principle: related operations are written as consecutive statements with **no blank line** between them. When the logical task changes, insert **one blank line**. Reading Zig code, blank lines are paragraph breaks — each paragraph is one coherent transformation.

### The discipline

1. **Stack related operations together (no blank line).** Operations that form one logical transformation are consecutive:

```zig
// ONE TASK: build a message
var msg: std.ArrayList(u8) = .empty;
try msg.appendSlice(allocator, header);
try msg.appendSlice(allocator, payload);
try msg.append(allocator, checksum);
```

2. **Separate unrelated operations with one blank line.** When the task changes:

```zig
// TASK 1: build the message
var msg: std.ArrayList(u8) = .empty;
try msg.appendSlice(allocator, header);
try msg.appendSlice(allocator, payload);
try msg.append(allocator, checksum);

// TASK 2: encode and send
const encoded = encode(msg.items);
try io.writer.writeAll(encoded);
```

Three visual groups: build, encode, send. A reader scanning the function sees three paragraphs and immediately understands the structure without reading any code.

3. **Minimize the stack.** Same discipline as Rust's chain minimization but for statements:
   - Can two statements be merged? `a = compute(x); b = transform(a);` → if `a` is used only once, inline it: `const b = transform(compute(x));`.
   - Is a temporary variable only used once and immediately? Inline it unless the name adds clarity.
   - Is a loop doing work that a stdlib call already does? Use the stdlib call.
   - Are two loops over the same data reading the same fields? Merge them into one loop.

### Patterns with examples

**Building a collection (reserve → fill):**
```zig
var result: std.ArrayList(Node) = .empty;
defer result.deinit(allocator);
try result.ensureTotalCapacity(allocator, estimated_count);
for (inputs) |input| result.appendAssumeCapacity(process(input));
```

Why `ensureTotalCapacity` + `appendAssumeCapacity`: one allocation, no per-element capacity checks. This is the DOD "reserve, don't grow" rule in action.

**Multi-pass transformation (each pass is a paragraph):**
```zig
// pass 1: count occurrences of each kind
var counts = [_]u32{0} ** Kind.count;
for (items) |item| counts[@intFromEnum(item.kind)] += 1;

// pass 2: prefix sum → offsets for scatter
var offsets: [Kind.count]u32 = undefined;
offsets[0] = 0;
for (1..Kind.count) |i| offsets[i] = offsets[i - 1] + counts[i - 1];

// pass 3: scatter items into sorted output
for (items) |item| {
    const slot = offsets[@intFromEnum(item.kind)];
    output[slot] = item;
    offsets[@intFromEnum(item.kind)] += 1;
}
```

This is a counting sort. Three paragraphs, three passes. Each paragraph maps to one pseudocode line. The algorithmic pattern (counting sort = count + prefix sum + scatter) is visible in the paragraph structure.

**Init + configure (one paragraph):**
```zig
var server = try std.http.Server.init(allocator, io);
defer server.deinit();
server.setMaxConnections(128);
server.setKeepAlive(true);
try server.listen(address);
```

All five lines are one task: set up the server. No blank lines between them.

**Conditional processing with early returns:**
```zig
const header = parseHeader(raw_bytes) orelse return error.MalformedHeader;
const payload_len = header.content_length;

const payload = raw_bytes[header.len..][0..payload_len];
const checksum = computeChecksum(payload);

if (checksum != header.expected_checksum) return error.ChecksumMismatch;
```

Three paragraphs: parse header, extract payload, verify checksum. The blank lines separate the logical phases. Error returns happen inline — they don't get their own paragraph because they're part of the step that checks them.

**SoA iteration (the common DOD pattern):**
```zig
const positions = particles.items(.pos);
const velocities = particles.items(.vel);

for (positions, velocities) |*p, v| {
    p[0] += v[0] * dt;
    p[1] += v[1] * dt;
    p[2] += v[2] * dt;
}
```

Two paragraphs: get the column slices, then iterate them together. The SoA access pattern is explicit — you can see which fields are touched (pos, vel) and which are not (everything else in the particle struct).

### When to use `inline for` vs runtime `for`

- `inline for` for comptime-known small sets (field iteration, enum values, tuple iteration):
  ```zig
  inline for (std.meta.fields(Config)) |field| {
      // process each field at compile time — generates specialized code per field
  }
  ```
- Runtime `for` for data arrays. Never `inline for` over data — it unrolls the loop entirely, bloating the binary and defeating the instruction cache.

### Variable declarations

- Declare at point of first use, not at the top of the function. The reader shouldn't have to scroll up to find what `x` is.
- `const` by default. `var` only when mutation is necessary. If you write `var` and never mutate, the compiler warns — but get it right on the first pass.
- Use `_` to discard unused captures: `for (items, 0..) |_, i|` when you only need the index.
- Prefer descriptive names for captures in multi-array iteration: `for (positions, velocities) |*pos, vel|` not `for (positions, velocities) |*a, b|`.

### Allocator discipline

Every function that allocates states it in the signature by taking `allocator: std.mem.Allocator`. This is non-negotiable in Zig — it's how the language enforces "caller owns memory":

```zig
// GOOD: caller provides allocator, caller controls memory strategy
fn tokenize(allocator: std.mem.Allocator, source: []const u8) ![]Token {
    var tokens: std.ArrayList(Token) = .empty;
    defer tokens.deinit(allocator);
    // ...
    return try tokens.toOwnedSlice(allocator);
}

// GOOD: caller provides output buffer, no allocation at all
fn tokenizeInto(source: []const u8, out: []Token) !usize {
    // ...
}
```

Prefer the `*Into` variant for hot paths — zero allocation, caller reuses the buffer.

For leak-freedom rules (ownership, `errdefer` pairing, arenas, leak-checking in tests), load [../../writing-leak-free-zig/SKILL.md](../../writing-leak-free-zig/SKILL.md).

## Formatting

- No trailing whitespace.
- 4-space indent (Zig standard).
- Opening braces on the same line: `if (cond) {`.
- One statement per line — never stack two statements on one line with `;`.
- Blank lines between paragraphs (as described above). No more than one consecutive blank line.
