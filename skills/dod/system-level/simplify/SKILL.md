---
name: simplify-code
description: "Simplify existing code by writing pseudocode of what each file does, taking a fresh look at the pseudocode only, then recreating the file minimally. Focuses on data movement — minimize cache misses, maximize cache hits. Use when user says 'simplify', 'clean up', 'reduce complexity', or wants to rewrite a file from scratch."
---

# Simplify Code

Strip a file to its essential data transformations. Two passes: extract intent, then reimplement from intent alone.

The insight: most code complexity comes from accumulated implementation details (error handling, defensive checks, intermediate buffers, compatibility shims, logging) that obscure the actual data flow. By extracting only the data transformations into pseudocode and reimplementing from that, you get a clean file that does the same thing with less code and better data access patterns.

## Process

### 1. Extract pseudocode from the existing file

For each file being simplified:

1. Read the file end to end.
2. Write a `.pseudocode` file (same name, `.pseudocode` extension) that captures **only what the file does**, not how:
   - One line per data transformation (see [pseudocode rules](../shared/pseudocode.md)).
   - State inputs and outputs at the top.
   - **Ignore:** error handling details, logging, defensive checks, helper abstractions, bookkeeping, compatibility workarounds.
   - **Name the data, not the operations.** Write `scores = weights * activations` not `call forward_pass(layer)`.

**Example — extracting pseudocode from a real function:**

Original (Rust, 45 lines):
```rust
fn process_orders(orders: &[Order], inventory: &mut Inventory) -> Vec<Receipt> {
    let mut receipts = Vec::new();
    let mut errors = Vec::new();
    for order in orders {
        if order.items.is_empty() { continue; }
        if order.total() <= 0.0 { errors.push(OrderError::InvalidTotal(order.id)); continue; }
        let mut fulfilled = Vec::new();
        for item in &order.items {
            match inventory.try_reserve(item.sku, item.qty) {
                Ok(reservation) => fulfilled.push(reservation),
                Err(e) => { /* rollback logic, logging, 15 lines */ }
            }
        }
        // ... tax calculation, discount application, receipt generation
        receipts.push(receipt);
    }
    receipts
}
```

Extracted pseudocode:
```
# process_orders.pseudocode
# in:  orders[N].{items[M].{sku, qty}, total}, inventory.{stock[K]}
# out: receipts[N].{order_id, items_fulfilled, total_charged}

filter orders: keep only non-empty with positive total    // linear scan
for each valid order:
    reserve inventory for each item                       // linear scan per order
    compute tax and discounts                             // arithmetic on order total
    emit receipt                                          // append to output
```

The 45-line function reduced to 4 pseudocode lines. The error handling, rollback logic, and logging are implementation details — the data transformation is: filter orders, reserve inventory, compute price, emit receipt.

### 2. Fresh-eyes pass (pseudocode only)

Close the original file. Work **only** from the `.pseudocode`. Pretend you've never seen the implementation:

- [ ] **Can any line be removed** without changing the output? (Does the output actually depend on this step?)
- [ ] **Can any two lines be merged** into one transformation? (Two loops over the same data → one loop. Two filters → one filter.)
- [ ] **Is any transformation redundant?** (Output never consumed downstream, or already computed elsewhere in the codebase.)
- [ ] **Is the data flow linear?** If it branches, is each branch necessary? (Sometimes a branch is defensive code for an impossible case.)
- [ ] **Are there intermediate data structures** that exist only to shuttle data between steps? Can the steps be fused to eliminate them? (Building a `Vec` just to iterate it → skip the `Vec`, chain the transformations.)

After this pass, the pseudocode should be shorter. If it isn't, the file was already minimal — that's fine, skip to step 4.

### 3. Data movement audit

For each remaining data transformation in the pseudocode, ask:

**What memory does it touch?**
- List every array/field read and written. If a step reads `particles.pos` and `particles.vel` but the struct also has `color`, `debug_id`, `sprite_index` — that's 3 fields dragged into cache for no reason.

**Is the access sequential or random?**
- Sequential (linear scan, streaming) = cache-friendly, prefetchable, autovectorizable.
- Random (hash lookup, pointer chase, tree traversal) = cache-unfriendly. Ask: is this genuinely necessary, or is there a sequential alternative?

**Are there unnecessary copies?**
- Data copied to an intermediate buffer then copied again → fuse the steps.
- Data serialized to a format then immediately deserialized → pass the original.

**Are cold fields mixed with hot fields?**
- If a transformation reads 2 of 8 fields across 10,000 elements but loads the whole struct (AoS), that's 75% wasted bandwidth. Mark these for SoA split.

**Can two passes be merged?**
- Two loops over `items[]` that each read `items[i].pos` → one loop. Saves a full data traversal.

**Annotate the pseudocode with findings:**

```
# in: particles[N].{pos, vel, mass, color, debug_id}
# out: particles[N].pos (updated)

positions += velocities * dt          // HOT: reads pos, vel. SoA wins.
apply_gravity(positions, masses)      // HOT: reads pos, mass. FUSE with line above — same loop.
# COLD: color, debug_id never touched in physics — split out of hot struct
# LAYOUT: AoS → SoA for pos, vel, mass. Side table for color, debug_id.
```

### 4. Reimplement from pseudocode

Recreate the file from the simplified, annotated pseudocode:

- Translate each pseudocode line using the language style rules ([rust-style](../rust-style/SKILL.md) or [zig-style](../zig-style/SKILL.md)).
- **Do not look at the original implementation** while writing. The pseudocode is the spec. If you peek at the old code, you'll unconsciously replicate its structure.
- **Add back only necessary error handling:** boundary validation (user input, external API), allocator failure, I/O errors. Don't re-add defensive checks for impossible internal states.
- **Apply layout changes** from the data movement audit (AoS→SoA, hot/cold split, fused loops).
- **Don't re-add logging, metrics, or debug code** unless the pseudocode explicitly marked it. Add those in a separate pass after the core is verified.

### 5. Verify

1. Compile.
2. Run existing tests. If they pass, the simplification preserved behavior.
3. If tests fail, diff the pseudocode against the original to find what transformation was dropped or changed.
4. Delete the `.pseudocode` file.

If the original had no tests, **this is the time to add them** — you now understand the data flow clearly enough to write precise, behavior-level tests.

## When NOT to simplify

- **Under 30 lines** and already reads like its pseudocode would.
- **Generated code** (protobuf, derive output, build scripts) — regenerate, don't hand-simplify.
- **Test files** — tests should be verbose and explicit. Simplifying tests makes them harder to debug when they fail.
- **FFI boundaries** — foreign function interfaces often have unavoidable ceremony (marshaling, null checks) that can't be simplified away.
- **Code you don't have tests for** and can't easily test — simplification without verification is just rewriting.
