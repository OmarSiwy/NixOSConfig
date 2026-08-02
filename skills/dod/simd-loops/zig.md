# The shape in Zig

Zig has generic vectors as a language feature, so no intrinsics, no `unsafe`, and no per-architecture duplication. The compiler lowers `@Vector` operations to whatever the target instruction set provides.

## The five parts

| Part | Zig |
|---|---|
| lane count | `std.simd.suggestVectorLength(T)` → `?comptime_int`, null when the target has no useful vector for `T` |
| vector type | `@Vector(lanes, T)` |
| splat | `const c: V = @splat(value);` |
| load a chunk | `const v: V = slice[i..][0..lanes].*;` |
| lane op | ordinary operators — `+`, `*`, `>`, `&` — apply elementwise |
| compare result | `@Vector(lanes, bool)` |
| reduce | `@reduce(.And, v)`, `.Or`, `.Add`, `.Min`, `.Max`, `.Xor` |
| mask → integer | `const m: std.meta.Int(.unsigned, lanes) = @bitCast(cmp);` |
| locate a lane | `@ctz(~m)` for first false, `@ctz(m)` for first true, `@popCount(m)` to count |
| blend | `@select(T, pred, a, b)` |
| permute | `@shuffle(T, a, b, mask)` |

`std.simd` wraps the common reductions: `firstTrue(mask)` → `?index`, `lastTrue`, `countTrues`, `iota`. Reach for these before hand-rolling the bitcast, and hand-roll when the index arithmetic needs to be fused with something else.

Guard the whole vector section on the lane-count query so targets without vectors skip it and fall through to the tail:

```zig
if (std.simd.suggestVectorLength(T)) |lanes| { ... }
```

## Reduce kind: locate the first element

Consume codepoints until one is at or below `0xF`:

```zig
var end: usize = 0;

if (std.simd.suggestVectorLength(u32)) |lanes| {
    const V = @Vector(lanes, u32);
    const threshold: V = @splat(0xF);
    while (end + lanes <= cps.len) : (end += lanes) {
        const values: V = cps[end..][0..lanes].*;
        const above = values > threshold;
        if (@reduce(.And, above)) continue;
        const mask: std.meta.Int(.unsigned, lanes) = @bitCast(above);
        end += @ctz(~mask);
        break;
    }
}

while (end < cps.len and cps[end] > 0xF) end += 1;
```

The `@reduce(.And, ...)` fast path skips the bitcast entirely on full vectors, which is the common case when printable runs are long. The final line is the original scalar loop, doing double duty as tail and fallback.

## Reduce kind: accumulate

Counting occurrences, in the idiom the standard library itself uses in `std.mem.countScalar`:

```zig
var i: usize = 0;
var found: usize = 0;

if (std.simd.suggestVectorLength(T)) |block_size| {
    const Block = @Vector(block_size, T);
    const needles: Block = @splat(element);
    while (list.len - i >= block_size) : (i += block_size) {
        const block: Block = list[i..][0..block_size].*;
        found += std.simd.countTrues(needles == block);
    }
}

for (list[i..]) |item| found += @intFromBool(item == element);
```

For a float sum, keep a `@Vector(lanes, f32)` accumulator across the chunk loop and `@reduce(.Add, acc)` once after it, rather than reducing every iteration — the whole point is to keep the fold in vector registers. Mind accumulator width: `countTrues` folding into a `usize` is safe, but summing `u8` lanes into a `@Vector(lanes, u8)` accumulator overflows within a chunk — widen the accumulator vector (e.g. `@Vector(lanes, u32)` for `u8` data).

## Gotchas

- **Vector length is independent of register width.** A vector shorter than the native SIMD width typically becomes one instruction; longer becomes several; an operation with no SIMD support becomes element-at-a-time scalar code. Powers of two from 2 to 64 are the useful range.
- **`suggestVectorLength` resolves at compile time against the compilation target.** Building with `-mcpu=native` bakes in the current machine's feature set, so a binary distributed to an older CPU will fault. Pick an explicit baseline `-mcpu` when shipping.
- **Comparisons produce `@Vector(n, bool)`, not an integer mask.** `@bitCast` to `std.meta.Int(.unsigned, lanes)` is the bridge, and it only works when `lanes` matches the integer's bit width.
- **The chunk loop condition must guarantee a full vector.** `slice[i..][0..lanes].*` on a short remainder is a compile error at best and an out-of-bounds read at worst; `while (i + lanes <= slice.len)` is the guard.
