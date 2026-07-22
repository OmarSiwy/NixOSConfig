---
name: rust-style
description: "Rust programming style rules. Nested iterator chains (.iter().map()...) are preferred but must be the minimal chain — no 9-call chain when 2 calls achieve the same result. Loaded by the system-level router when writing Rust code."
---

# Rust Programming Style

Applies after the [problem mapping](../shared/problem-mapping.md) and [pseudocode](../shared/pseudocode.md) steps are done. This skill governs **how** the Rust code reads, not what it does.

For DOD, memory, concurrency, and type design rules, load [../../Brogramming/principles/rust.md](../../Brogramming/principles/rust.md).

## Core rule: minimal nested chains

Rust supports nested method chains (`.iter().map().filter().collect()`). **Always prefer chaining over intermediate bindings** — but the chain must be the **shortest possible chain** that achieves the intended transformation.

The principle: a chain is a sentence describing a data transformation. A 2-call chain that does the job is better than a 9-call chain, even if the 9-call chain is "more expressive." Minimize combinators the way you minimize pseudocode lines.

### The discipline

1. **Chain, don't split.** If a transformation can be expressed as one chain, write one chain. No `let intermediate = ...` followed by `intermediate.iter()...` when the whole thing composes.

2. **Minimize the chain.** After writing a chain, audit it:
   - Can two adjacent combinators be merged into one? (`.map(f).map(g)` → `.map(|x| g(f(x)))`)
   - Is there a single combinator that replaces a multi-step sequence? (`.map().flatten()` → `.flat_map()`)
   - Is the chain doing work that the type system already guarantees? Remove it.
   - Could a different starting point shorten the chain? (`.iter().enumerate().filter(|(i, _)| ...).map(|(_, v)| v)` — maybe a direct index loop is shorter.)
   - Are you collecting just to re-iterate? (`.collect::<Vec<_>>()` followed by `.iter()...` → remove the collect, keep chaining.)

3. **Read as a sentence.** The chain should read as a single English sentence describing the transformation. If you can't state what it does in one sentence, the chain is doing too much — break the *logic* into meaningful functions, then chain those.

### Common reductions

```rust
// BAD: 4 calls when 2 suffice
items.iter().map(|x| x.name).filter(|n| !n.is_empty()).collect::<Vec<_>>()
// GOOD: filter_map merges filter + map
items.iter().filter_map(|x| (!x.name.is_empty()).then_some(x.name)).collect()

// BAD: map then flatten
results.iter().map(|r| r.errors()).flatten().collect::<Vec<_>>()
// GOOD: flat_map
results.iter().flat_map(|r| r.errors()).collect::<Vec<_>>()

// BAD: collect to re-iterate
let ids: Vec<_> = items.iter().map(|x| x.id).collect();
let sum: u64 = ids.iter().sum();
// GOOD: don't collect, keep chaining
let sum: u64 = items.iter().map(|x| x.id).sum();

// BAD: enumerate when you only need the index
items.iter().enumerate().map(|(i, _)| i * 2).collect::<Vec<_>>()
// GOOD: range
(0..items.len()).map(|i| i * 2).collect::<Vec<_>>()

// BAD: cloned() then iter() on the clone
let v: Vec<_> = items.iter().cloned().collect();
v.iter().for_each(|x| process(x));
// GOOD: just borrow
items.iter().for_each(|x| process(x));

// ALREADY MINIMAL — don't try to reduce further:
xs.iter().map(|x| x * x).sum::<f64>()          // 3 calls, each does distinct work
positions.iter_mut().zip(&velocities).for_each(|(p, v)| *p += v * dt)  // zip + for_each is the right shape
```

### Chaining with `?` (error propagation)

For fallible chains, `.collect::<Result<Vec<_>, _>>()?` is idiomatic. Don't manually loop + push + `?` unless the error handling has side effects.

```rust
// Parse all lines, propagate the first error:
let configs: Vec<Config> = lines.iter().map(|l| parse_line(l)).collect::<Result<_, _>>()?;

// With context per element:
let configs: Vec<Config> = lines
    .iter()
    .enumerate()
    .map(|(i, l)| parse_line(l).with_context(|| format!("line {i}")))
    .collect::<Result<_, _>>()?;
```

### When to break a chain

- **The chain exceeds ~5 combinators** and you can't reduce it — extract the transformation into a named function, then call it in a shorter chain.
- **Side effects** — if a step needs mutation, logging, or early return beyond `?`, use a `for` loop.
- **Multiple outputs** — if you're accumulating into two different collections, a `for` loop is clearer than `fold` with a tuple.
- **Readability** — if a colleague would need to trace types through more than 3 generic transformations, extract a named function.

```rust
// BAD: chain doing too much, hard to read
let result: HashMap<String, Vec<u32>> = items
    .iter()
    .filter(|x| x.active)
    .map(|x| (x.category.clone(), x.score))
    .fold(HashMap::new(), |mut acc, (k, v)| { acc.entry(k).or_default().push(v); acc });

// GOOD: extract the grouping logic
fn group_scores(items: &[Item]) -> HashMap<String, Vec<u32>> {
    let mut groups = HashMap::new();
    for item in items.iter().filter(|x| x.active) {
        groups.entry(item.category.clone()).or_default().push(item.score);
    }
    groups
}
```

## Formatting

- One combinator per line when the chain exceeds the line width. Align the dots:

```rust
positions
    .iter_mut()
    .zip(&velocities)
    .for_each(|(p, v)| *p += v * dt);
```

- Single-line chains when they fit comfortably (< ~80 chars):

```rust
let sum: f64 = xs.iter().map(|x| x * x).sum();
let alive: Vec<_> = particles.iter().filter(|p| p.alive).collect();
```

- Multi-line closures get their own block:

```rust
events
    .iter()
    .filter_map(|e| match e.kind {
        EventKind::Click { x, y } if bounds.contains(x, y) => Some((x, y)),
        _ => None,
    })
    .for_each(|(x, y)| handle_click(x, y));
```

## Beyond chains

Not everything is an iterator chain. These situations call for plain loops:

- **Multiple outputs** from one pass — accumulate into two vecs, compute two statistics simultaneously.
- **Complex control flow** — early break with state-dependent conditions, nested loops with cross-iteration state.
- **Performance-critical SIMD** — explicit `chunks_exact` processing with manual vectorization.
- **Index-heavy operations** — when you need `items[i-1]` and `items[i+1]` alongside `items[i]`.

When you write a plain loop, the stacking rule from [Zig style](../zig-style/SKILL.md) applies here too: group related operations together, separate logically distinct operations with a blank line.

```rust
// Two outputs from one pass — loop is clearer than fold-with-tuple
let mut sum = 0u64;
let mut count = 0u32;
for item in &items {
    sum += item.value;
    count += 1;
}

// Index-heavy: checking neighbors
for i in 1..items.len() - 1 {
    if items[i] > items[i - 1] && items[i] > items[i + 1] {
        peaks.push(i);
    }
}
```
