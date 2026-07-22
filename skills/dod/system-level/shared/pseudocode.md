# Pseudocode Workflow

Write pseudocode before writing real code. The pseudocode is a contract — the implementation is a minimal translation of it, nothing more.

Why: pseudocode strips away language ceremony (types, error handling, allocation, imports) and forces you to see the data flow. If the pseudocode is wrong, the code will be wrong with better syntax. If the pseudocode is right, translating it is mechanical.

---

## Process

### 1. Create the `.pseudocode` file

Name it after the module or function: `parser.pseudocode`, `physics_step.pseudocode`, `route_match.pseudocode`.

Place it next to the file it will become (same directory). It's temporary — deleted after implementation is verified.

### 2. Write the pseudocode

Rules:
- **One line per data transformation.** Not one line per statement — one line per meaningful step. If a step does two things, it's two lines.
- **Name the data, not the operations.** Write `positions += velocities * dt` not `call update_physics for each entity`. The data is the program; the function names are just labels.
- **Use the architectural pattern names** from the [problem mapping step](problem-mapping.md) as section headers. If you mapped the problem to "Pipe and Filter + FSM," your pseudocode has sections labeled `# pipe stage: parse` and `# FSM: lexer states`.
- **Use the algorithmic pattern names** as inline labels: `// two-pointer scan`, `// prefix sum build`, `// linear scan`. This makes the algorithmic choices explicit and auditable.
- **No language syntax.** No types, no error handling, no imports, no allocation, no semicolons. Just the data flow.
- **State what goes in and what comes out** at the top of each block (Acton's P1: "what data in, what data out"). This is the function signature, stripped to data.

### 3. Review the pseudocode (fresh-eyes pass)

Before implementing, read the pseudocode as if someone else wrote it:

- [ ] Can every line be stated as "input → transform → output"?
- [ ] Is there a line that doesn't transform data? (logging, bookkeeping, metrics) — mark it as `COLD` or remove it.
- [ ] Can any two adjacent lines be merged into one? If yes, merge. (Two passes over the same array that read the same fields → one pass.)
- [ ] Can any line be removed entirely without changing the output? If yes, remove.
- [ ] Is the data flow linear (pipe) or does it branch? If it branches, is each branch necessary?
- [ ] Are there intermediate data structures that exist only to shuttle data between steps? Can the steps be fused to eliminate the intermediate?

After this pass, the pseudocode should be shorter. If it isn't, the file was already minimal — that's fine.

### 4. Implement minimally

Translate each pseudocode line into the target language:

- **One pseudocode line → the fewest language statements that achieve it.** Not the fewest characters — the fewest distinct operations.
- **Don't add what the pseudocode didn't say.** No speculative error handling, no extra fields, no "nice to have" helpers, no logging unless the pseudocode says `COLD: log`.
- **Use the language style rules** from the detected language skill ([rust-style](../rust-style/SKILL.md) or [zig-style](../zig-style/SKILL.md)) for how to chain/stack calls.
- **Delete the `.pseudocode` file** once the implementation compiles and the tests pass. It served its purpose. The implementation is now the source of truth.

---

## Examples

### Example A: Physics update (simple)

```
# physics_step.pseudocode
# in:  positions[N], velocities[N], dt
# out: positions[N] (updated in place)

positions += velocities * dt          // linear scan, autovectorizable
clamp positions to world_bounds       // linear scan, branchless select
```

Two lines. Two data transformations. That's the whole step.

**Zig translation:**
```zig
for (positions, velocities) |*p, v| {
    p.* += v * @as(@TypeOf(v), @splat(dt));
    p.* = @max(world_min, @min(world_max, p.*));
}
```

**Rust translation:**
```rust
positions.iter_mut().zip(&velocities).for_each(|(p, v)| {
    *p += v * dt;
    *p = p.clamp(world_min, world_max);
});
```

Both are minimal translations. The pseudocode had 2 lines; each implementation has 2 data operations. Nothing was added.

### Example B: HTTP request routing (multi-stage pipe)

```
# route_match.pseudocode
# in:  raw_bytes[]
# out: response_bytes[]

# --- pipe stage: parse ---
# in: raw_bytes[]  out: method, path, headers, body
method, path = extract from raw_bytes up to first \r\n    // linear scan
headers = extract key:value pairs until empty line          // linear scan
body = remaining bytes after headers                        // pointer arithmetic

# --- pipe stage: match ---
# in: method, path  out: handler_id
handler_id = look up (method, path) in route_table          // trie traversal or hash lookup

# --- pipe stage: dispatch ---
# in: handler_id, headers, body  out: response_bytes
response = call handler[handler_id] with (headers, body)    // index into handler array
response_bytes = serialize response                         // linear scan
```

Three pipe stages, clearly separated. Each has explicit in/out. The architectural pattern (Pipe and Filter) is visible in the section headers. The algorithmic pattern (linear scan, trie traversal) is visible in the inline labels.

### Example C: Counting sort (algorithmic)

```
# sort_by_kind.pseudocode
# in:  items[N] with items[i].kind : enum(0..K)
# out: sorted_items[N] (grouped by kind)

# --- pass 1: count ---                        // linear scan
counts[K] = 0
for each item: counts[item.kind] += 1

# --- pass 2: prefix sum ---                   // prefix sum build
offsets[K] where offsets[i] = sum(counts[0..i])

# --- pass 3: scatter ---                      // linear scan
for each item:
    sorted_items[offsets[item.kind]] = item
    offsets[item.kind] += 1
```

Three passes, each a linear scan. The pseudocode uses the algorithmic pattern names ("prefix sum build") inline. A model reading this knows exactly what data structure and algorithm to use in the implementation.

### Example D: Bad pseudocode vs good pseudocode

**Bad** (names operations, not data):
```
initialize the particle system
for each particle:
    call update_physics(particle)
    call check_collision(particle, world)
    call render(particle)
clean up resources
```

This tells you nothing about the data. What fields are read? What's written? What's the access pattern? It's just function names.

**Good** (names data, states access pattern):
```
# in:  pos[N], vel[N], mass[N], alive[N], dt
# out: pos[N] (updated), alive[N] (updated)

vel += gravity * dt                           // linear scan, uniform value
pos += vel * dt                               // linear scan, autovectorizable

# --- spatial hash for collision ---
grid_cells = assign each pos to grid cell     // linear scan + scatter
for each cell with >1 particle:               // sparse iteration
    check pairs within cell → mark dead       // N² within cell, but cells are small

# COLD: render (separate pass, different data)
# reads: pos[N], sprite[N] (not vel, mass)
```

This pseudocode tells you: `vel` and `pos` are hot (touched every frame), `mass` is read-only, `sprite` is only read by the render pass (cold relative to physics). SoA layout is obviously correct. The collision detection uses a spatial hash (architectural choice made explicit). The render pass reads different fields — confirming the hot/cold split.

---

## When to skip pseudocode

- The change is a one-line fix to an existing function.
- The change is purely mechanical (rename, move, re-export).
- The file is under 20 lines and the transformation is obvious from the function signature.

If you're unsure whether to write pseudocode, write it. It takes 2 minutes and prevents 20 minutes of wrong-direction coding.
