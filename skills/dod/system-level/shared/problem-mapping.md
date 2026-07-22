# Problem Mapping

Two lenses applied before any code is written. Both are pen-and-paper exercises — no implementation yet.

The goal: before you touch a keyboard, you should be able to say "this problem is [architectural pattern] because [reason], decomposed into [algorithmic subproblems] with [complexities]." If you can't, you don't understand the problem yet.

---

## 1. Architectural Pattern Mapping

Source: [architectural-patterns.net/pattern-tree](https://architectural-patterns.net/pattern-tree), filtered and ranked by data-orientation. OOP-heavy patterns that impose object hierarchies, virtual dispatch, or hide data layout are moved to Tier 3 or removed entirely.

### How to use this catalog

1. **Read the problem statement.** What data goes in? What data comes out?
2. **Scan Tier 1 first.** Most system-level problems map to 1–3 of these patterns.
3. **Name the mapping explicitly:** "This is a [Pipe and Filter] because data flows through [lexer → parser → codegen] stages" — not "I think we should use Pipe and Filter."
4. **If nothing in Tier 1 fits,** check Tier 2 for structural patterns. Tier 3 only when the problem genuinely requires the trade-off.

### Tier 1 — Data-first (default to these)

Patterns inherently about data transformation, data flow, or data layout. Compose naturally with DOD.

**Pipe and Filter** — Data flows through transformation stages. Each stage is a pure function over contiguous input.
- Data shape: stream or buffer between stages.
- Example: A compiler is `source_bytes → tokens → AST → IR → machine_code`. Each stage reads a contiguous array and produces a contiguous array. Unix shell pipes (`cat file | grep pattern | sort | uniq`) are the same shape.
- Example: An audio processor chains `decode → normalize → apply_eq → resample → encode`. Each filter reads an `f32` sample buffer, writes an `f32` sample buffer.
- Example: An image pipeline: `load_png → resize → apply_filter → encode_jpg`. Each step takes a pixel buffer, outputs a pixel buffer.
- DOD: Each pipe is a contiguous buffer. Filters are stateless transforms. No shared mutable state between stages.

**Entity-Component-System (ECS)** — Many entities, each a bag of components. Systems iterate component arrays. The DOD poster child.
- Data shape: SoA — one array per component type, entity = index into those arrays.
- Example: A game world has 10,000 entities. Each entity may have `Position`, `Velocity`, `Health`, `Sprite` components. The physics system iterates `positions[]` and `velocities[]` together (ignoring Health, Sprite). The render system iterates `positions[]` and `sprites[]` (ignoring Velocity, Health). Each system touches only the columns it needs.
- Example: The Zig compiler uses this pattern internally — AST nodes are stored SoA via `MultiArrayList`, with systems that iterate specific fields for type checking, codegen, etc.
- Real implementations: Bevy (Rust), EnTT (C++), flecs (C), Zig's own compiler.
- DOD: The defining data pattern. Components are stored as parallel arrays. Systems are pure functions over column slices. Adding a new component doesn't touch existing systems.

**ETL (Extract-Transform-Load)** — Explicit data pipeline: pull from source, transform, push to sink.
- Data shape: batch arrays through stages.
- Example: A log ingestion pipeline: extract log lines from files → transform (parse timestamps, extract fields, normalize) → load into a columnar database. Each stage operates on batches of rows.
- Example: A build system: extract source files → transform (compile each) → load (link into binary).
- DOD: Same as Pipe and Filter but emphasizes batch processing. Each stage should operate on arrays, not single elements.

**Event Sourcing** — Append-only log of events. Current state = fold over the log.
- Data shape: contiguous event log array, plus periodic snapshots for fast reload.
- Example: A banking system stores events `[Deposit(100), Withdraw(50), Deposit(200)]`. Current balance = fold: `0 + 100 - 50 + 200 = 250`. To replay or audit, re-fold from any point.
- Example: Git is event sourcing — each commit is an event. The working directory is the current state derived by folding commits.
- Example: A multiplayer game stores input events per frame. Replay = re-apply events from frame 0. Desync detection = compare state hashes at checkpoints.
- DOD: The event log is a contiguous array of tagged structs. Folding it is a linear scan. Snapshots are periodic state dumps that avoid re-folding from the beginning.

**CQRS (Command-Query Responsibility Segregation)** — Separate read path from write path.
- Data shape: write model (normalized, optimized for mutations) + read model (denormalized/SoA, optimized for queries).
- Example: A product catalog. Writes update a normalized `products` table. Reads query a denormalized view with `product + category + pricing + inventory` pre-joined and stored SoA for fast column scans.
- Example: A search engine. Writes append documents to an ingest queue. Reads query an inverted index built asynchronously from the write path.
- DOD: The read model is where SoA pays off — queries iterate specific fields across many records. The write model can be AoS since writes touch all fields of one record.

**Finite State Machine** — State transitions driven by input data. State is an enum, transitions are a table.
- Data shape: `enum` state + transition table (array indexed by `[state][input]`, or a `match` block).
- Example: A network protocol handler: states = `Disconnected`, `Connecting`, `Connected`, `Closing`. Inputs = `syn_received`, `ack_received`, `timeout`, `close_requested`. Each `(state, input)` pair maps to a `(next_state, action)`.
- Example: A lexer: states = `Start`, `InNumber`, `InString`, `InComment`. Each byte of input triggers a transition. The state machine is a tight loop over a byte array with a `switch` on state.
- Example: A UI component: states = `Idle`, `Hovered`, `Pressed`, `Disabled`. Mouse events drive transitions.
- DOD: The transition table is a 2D array `[num_states][num_inputs]` — contiguous, cache-friendly, no virtual dispatch. Processing input is a linear scan over the input array.

**Game Loop** — Fixed-tick update loop. Each tick transforms world state.
- Data shape: arrays of components updated per tick.
- Example: `while running: { input = poll_events(); state = update(state, input, dt); render(state); }`. Each phase operates on the full world state arrays.
- Example: A simulation: `while t < t_end: { forces = compute_forces(positions, masses); velocities += forces * dt; positions += velocities * dt; t += dt; }`.
- DOD: Combines naturally with ECS. The loop is the outermost Pipe: `input → update → render`, with update itself being multiple system passes over component arrays.

**Index** — Precomputed data structure for fast lookup.
- Data shape: sorted arrays, hash tables, trees, inverted indices — pick by access pattern.
- Example: A search engine's inverted index: `word → [doc_id, doc_id, ...]`. Built once (or incrementally), queried many times.
- Example: A spatial index (quadtree, BVH) for collision detection: given a bounding box, return all objects that overlap.
- Example: A database B-tree index on a column for O(log n) range queries.
- DOD: The index is a secondary data structure built from the primary data. Keep the primary data in SoA layout; the index holds indices (u32) into those arrays.

**Cache** — Store computed results for reuse.
- Data shape: key→value, often LRU with contiguous backing array.
- Example: A font renderer caches rasterized glyphs: `(font_id, glyph_id, size) → bitmap`. Computing a glyph is expensive; looking it up in the cache is O(1).
- Example: A web server caches rendered HTML pages: `url → response_bytes`. Avoids re-rendering on every request.
- DOD: Use a flat hash map (open addressing) for cache-friendly lookups. LRU eviction with an array-backed doubly-linked list (indices, not pointers).

**Parallel Programming** — Same transformation on disjoint data partitions.
- Data shape: partitioned arrays, no shared mutable state.
- Example: Updating positions for 100,000 particles. Split into 8 chunks of 12,500. Each thread gets one chunk (disjoint `&mut [Position]` slice). No locks needed.
- Example: Map-reduce: map phase partitions input across workers, reduce phase merges results.
- DOD: SoA layout makes partitioning clean — each worker gets a contiguous slice of each column. False sharing is prevented by aligning chunk boundaries to cache lines.

**Transaction** — Atomic batch of data mutations. All-or-nothing.
- Data shape: write set (list of `(address, old_value, new_value)`) or undo log.
- Example: A database transaction: `BEGIN; UPDATE accounts SET balance = balance - 100 WHERE id = 1; UPDATE accounts SET balance = balance + 100 WHERE id = 2; COMMIT;`. If either update fails, both are rolled back.
- Example: A file system operation: move file involves `create_link + remove_old_link`. If the second step fails, undo the first.

**Snapshot Sequence** — Periodic full-state captures for fast restore or time-travel.
- Data shape: contiguous state dump at checkpoints.
- Example: A game saves a checkpoint every 60 seconds. Player dies → restore from last checkpoint (memcpy the state arrays back).
- Example: Database WAL (write-ahead log) + periodic checkpoints. Recovery = load last checkpoint + replay WAL entries after it.

**Undo** — Reverse data mutations.
- Data shape: command stack (list of `(do, undo)` pairs) or diff list.
- Example: A text editor stores each edit as a command: `Insert(pos, text)` / `Delete(pos, len)`. Undo pops the stack and applies the inverse.
- Example: A drawing app stores strokes. Undo removes the last stroke from the layer's stroke array.

### Tier 2 — Structural (no OOP overhead when used correctly)

Organize code boundaries without imposing object hierarchies. Compatible with DOD when data stays transparent.

**Layers** — Separate concerns by data flow direction (input → logic → output).
- Example: A web server: `HTTP parsing layer → routing layer → business logic layer → database layer`. Each layer passes plain data structs to the next.
- DOD note: Keep data transparent across layers. Don't hide layout behind layer boundaries. A layer owns a transformation, not the data.

**Bounded Context** — Different parts of the system own different data.
- Example: An e-commerce system: `Catalog` context owns product data, `Orders` context owns order data. They share a `product_id` but not internal representations. Data crosses boundaries via explicit DTOs.
- DOD note: Each context owns its data layout independently. The `Catalog` might store products SoA for fast search; `Orders` stores order lines AoS for per-order processing.

**Hexagonal Architecture (Ports and Adapters)** — Core logic is pure data transformation. I/O enters through ports.
- Example: A payment processor's core: `fn process_payment(payment: Payment) -> Result<Receipt, Error>`. The core knows nothing about HTTP or databases. Adapters translate `HttpRequest → Payment` and `Receipt → HttpResponse`.
- DOD note: Ports are data interfaces (structs/enums), not object interfaces (traits with methods). Adapters are functions that translate external data formats into internal SoA layouts.

**Microkernel** — Minimal core, extensions are plugins.
- Example: An editor core handles buffer management. Syntax highlighting, auto-complete, and linting are plugins that register `fn(buffer_state) -> annotations`.
- DOD note: Plugins register data transformations (function pointers + metadata struct). Core dispatches by tag/enum, not vtable. Plugin data is stored in arrays managed by the core.

**Publish-Subscribe** — Decouple producers from consumers via event data.
- Example: A UI framework: button click emits `Event::Click { x, y, button_id }`. Multiple listeners (tooltip handler, form validator, analytics) each receive the event independently.
- DOD note: Events are plain data structs. Where possible, batch-deliver events (subscriber processes an array of events) rather than one-at-a-time callback invocation.

**Message Queue** — Async data delivery between stages.
- Example: A web app enqueues `SendEmail { to, subject, body }` messages. A background worker dequeues and processes them. The web handler returns immediately.
- DOD note: Messages are contiguous in the queue (ring buffer). Batch dequeue > per-message dequeue. Each message is a tagged union (enum).

**Repository** — Data storage abstraction.
- Example: `fn get_users_by_role(role: Role) -> Vec<User>`. Returns contiguous data. Abstracts whether it's from Postgres, SQLite, or an in-memory array.
- DOD note: Return contiguous collections, not iterator-of-objects. Bulk operations (`insert_batch`, `update_where`) over single-entity CRUD.

**Lifecycle Hooks** — Init → run → cleanup phases.
- Example: A web server: `on_startup` (load config, warm caches) → `on_request` (handle traffic) → `on_shutdown` (drain connections, flush logs). Each phase has its own arena allocator.
- DOD note: Arena per phase. Phase data is freed all at once when the phase ends.

**Blackboard** — Shared data space, multiple independent knowledge sources contribute.
- Example: A compiler's symbol table is a blackboard. The parser writes symbols, the type checker reads and annotates them, the optimizer reads annotations and writes optimized versions. All modify the same shared data structure.
- DOD note: The blackboard IS the data structure. Knowledge sources are stateless transforms that read from and write to it.

### Tier 3 — Use with caution (OOP-leaning or indirection-heavy)

These patterns can work but tend to pull toward object hierarchies, virtual dispatch, or hidden data flow. Use only when the problem genuinely requires the specific trade-off.

| Pattern | Why caution | DOD alternative |
|---|---|---|
| **MVC / MVP / MVVM** | Framework-imposed object hierarchy. View ↔ Model binding hides data flow. | Pipe-and-filter: `input → state_transform → render`. State is plain data. Example: Elm architecture — `Model` is a struct, `update` is a pure function, `view` renders from the model. |
| **Software Framework** | Inverts flow control ("don't call us, we'll call you"). Hides data paths. | Library + explicit data flow. You own the loop. Example: Use `hyper` (library, you call it) over `actix-web` (framework, it calls you) when you need control. |
| **Broker / SOA / Microservices** | Serialization + network = real overhead per call. Legitimate for distributed systems. | Monolith with bounded contexts until you prove you need distribution. Then explicit data contracts (protobuf, flatbuffers) between services. |
| **ORM** | Hides data layout behind object abstraction. Defeats SoA. Generates unpredictable queries (N+1 problem). | Direct queries returning contiguous result sets. Map to SoA structs at the boundary. Example: `sqlx::query_as!` in Rust returns typed rows you control. |
| **Interpreter** | Dynamic dispatch per instruction in the hot loop. | Bytecode + `switch`/`match` dispatch over a contiguous instruction array. Example: Lua, CPython, and the JVM all use bytecode dispatch, not AST interpretation, in their hot paths. |

### Removed (pure OOP ceremony)

Not included: SOLID principles as patterns, Entity/Value Object/Aggregate/DTO class taxonomy, package design principles (REP, CCP, CRP, SDP, SAP). These are object-oriented design vocabulary. When you need the underlying idea (e.g. "don't depend on things that change more than you"), apply it directly — don't reach for the OOP framing.

---

## 2. Algorithmic Decomposition (Leetcode Lens)

Every non-trivial computation decomposes into well-known algorithmic subproblems. Ranked by cache-friendliness and data-orientation.

### How to use this catalog

1. **Describe the computation in one sentence.** "Find the K most frequent words in a stream of documents."
2. **Decompose into subproblems.** "Count word frequencies (linear scan + hash map), then find top-K (heap)."
3. **Check the tier of each subproblem.** Hash map = Tier 3, heap = Tier 2. Can we replace the hash map? If the vocabulary is bounded, counting sort (Tier 1) works. If not, the hash map is necessary.
4. **State complexities.** "O(n) to count, O(n log k) for top-K. Total: O(n log k)."

### Tier 1 — Cache-friendly, data-parallel, contiguous access

Default to these. They iterate contiguous memory, minimize cache misses, and often autovectorize.

**Linear scan** — Sequential, single pass. O(n) time, O(1) space.
- Use for: search, filter, transform, accumulate over a contiguous array.
- Example: Find max element. Sum an array. Filter particles by alive flag. Map positions by adding velocity*dt.
- Leetcode: #53 Maximum Subarray (Kadane's is a linear scan variant), #1 Two Sum (brute force: nested linear scan), #136 Single Number (XOR accumulate).
- DOD: The bread and butter. A linear scan over a contiguous `[]f32` or `Vec<f32>` is what autovectorizes. SoA layout ensures each scan touches only the fields it needs.

**Two pointers** — Two indices moving through contiguous data. O(n) time, O(1) space.
- Use for: sorted array operations, partitioning, palindrome check, merging two sorted arrays.
- Example: Remove duplicates from a sorted array — slow pointer tracks write position, fast pointer scans ahead. Merge step of merge sort — one pointer per input array.
- Leetcode: #26 Remove Duplicates, #11 Container With Most Water, #15 3Sum (sort + two-pointer inner loop), #125 Valid Palindrome.
- DOD: Both pointers walk contiguous memory. No random access. The hardware prefetcher handles both streams.

**Sliding window** — Fixed or variable window over contiguous data. O(n) time, O(1) or O(k) space.
- Use for: substring/subarray problems, running statistics, streaming aggregation.
- Example: Maximum sum of any subarray of length K — maintain running sum, subtract leaving element, add entering element. Longest substring without repeating characters — variable window that grows/shrinks.
- Leetcode: #3 Longest Substring Without Repeating Characters, #76 Minimum Window Substring, #239 Sliding Window Maximum.
- DOD: The window moves sequentially through contiguous data. Hot data stays in cache because the window only touches elements near its edges.

**Prefix sum / difference array** — O(n) build, O(1) per range query.
- Use for: range sum queries, range updates, cumulative frequency, computing running averages.
- Example: Given an array of daily sales, answer "total sales from day L to day R" in O(1) after O(n) precomputation: `prefix[R+1] - prefix[L]`.
- Example: Difference array for range updates: to add 5 to all elements from index L to R, do `diff[L] += 5; diff[R+1] -= 5;`, then prefix-sum to get the final array.
- Leetcode: #303 Range Sum Query, #304 Range Sum Query 2D, #560 Subarray Sum Equals K.
- DOD: The prefix array is built by a single sequential pass. Queries are O(1) array lookups. Extremely cache-friendly.

**Counting sort / radix sort** — O(n+k) time, O(k) space. No comparisons.
- Use for: sorting integers with bounded range. Sorting strings by character.
- Example: Sort 1 million ages (0–150). Create `counts[151]`, scan once to count, prefix-sum to get positions, scatter into output. Three sequential passes over contiguous data.
- Leetcode: #75 Sort Colors (special case: k=3, Dutch national flag), #274 H-Index.
- DOD: Three linear passes. No comparisons, no branch mispredictions. Cache-friendly. The count array fits in L1 for small k.

**Bit manipulation** — Register-width operations, branchless. O(1) to O(n) time, O(1) space.
- Use for: flags, masks, parity, set operations on small sets, finding missing/duplicate elements.
- Example: XOR all elements to find the single non-duplicate: `a ^ a = 0`, so duplicates cancel. Check if power of 2: `n & (n-1) == 0`. Count set bits: `popcount`.
- Leetcode: #136 Single Number, #191 Number of 1 Bits, #338 Counting Bits, #268 Missing Number.
- DOD: Branchless, fits in registers. Bit arrays are the densest possible representation of boolean data.

**Merge sort** — O(n log n) time, O(n) space. Sequential access in the merge step. Stable.
- Use for: external sort (data too large for RAM), stable sort requirement, merge-K-sorted-lists.
- Leetcode: #148 Sort List, #23 Merge K Sorted Lists (heap-merge variant).
- DOD: The merge step reads two input arrays sequentially and writes one output array sequentially. Cache-oblivious — works well at every level of the memory hierarchy.

**Kadane's algorithm** — Single pass, running max. O(n) time, O(1) space.
- Use for: maximum subarray sum, best time to buy and sell stock.
- Leetcode: #53 Maximum Subarray, #121 Best Time to Buy and Sell Stock.

**Dutch national flag** — Three pointers, single pass. O(n) time, O(1) space, in-place.
- Use for: three-way partitioning (0/1/2 sort, partition around pivot with equal elements).
- Leetcode: #75 Sort Colors.

**Boyer-Moore voting** — Single pass, O(1) state. O(n) time, O(1) space.
- Use for: finding the majority element (element appearing > n/2 times).
- Leetcode: #169 Majority Element.

### Tier 2 — Good locality, moderate overhead

Array-backed or log-depth structures. Reasonable cache behavior.

**Binary search** — O(log n) time, O(1) space. Halving over sorted contiguous data.
- Use for: sorted array lookup, finding boundaries, search for optimal value (binary search on answer).
- Example: Find the first element ≥ target in a sorted array. Binary search on answer: "what's the minimum speed to finish all tasks in H hours?"
- Leetcode: #33 Search in Rotated Sorted Array, #34 Find First and Last Position, #875 Koko Eating Bananas (binary search on answer).
- DOD: The data must be sorted and contiguous. The access pattern (halving) touches O(log n) cache lines — far fewer than a linear scan for large n, but with random access.

**Stack / monotonic stack** — O(n) time, O(n) space. LIFO means top of stack is always cache-hot.
- Use for: next greater/smaller element, matching brackets, histogram problems, expression parsing.
- Example: For each element, find the next greater element to its right. Push indices onto stack. When current element is greater than stack top, pop and record answer.
- Leetcode: #84 Largest Rectangle in Histogram, #20 Valid Parentheses, #739 Daily Temperatures.
- DOD: The stack is an array (`Vec<u32>` of indices). Top-of-stack access is always the same cache line. Push/pop are sequential.

**Heap / priority queue** — O(log n) per insert/extract. Array-backed binary tree.
- Use for: top-K elements, merge-K-sorted, shortest path (Dijkstra), scheduling.
- Example: Find the K largest elements in a stream. Maintain a min-heap of size K. Each new element: if larger than heap min, replace and sift down.
- Leetcode: #215 Kth Largest Element, #23 Merge K Sorted Lists, #295 Find Median from Data Stream.
- DOD: A binary heap stored as an array has good locality — parent and children are nearby in memory. Prefer over a balanced BST (pointer-chasing).

**DP (bottom-up tabulation)** — Sequential table fill. Varies in time, O(n) to O(n²) space.
- Use for: optimization, counting, sequence alignment, shortest path in DAGs.
- Example: Fibonacci: `dp[i] = dp[i-1] + dp[i-2]`. Edit distance: `dp[i][j] = min(dp[i-1][j]+1, dp[i][j-1]+1, dp[i-1][j-1] + (a[i]!=b[j]))`.
- Leetcode: #70 Climbing Stairs, #322 Coin Change, #72 Edit Distance, #300 Longest Increasing Subsequence.
- DOD: Bottom-up fills the table sequentially — row by row, cell by cell. This is cache-friendly. Top-down memoization (Tier 3) accesses the table randomly. **Always prefer bottom-up when you know the dependency order.**

**Union-Find (Disjoint Set)** — Near O(α(n)) per operation (~O(1) amortized). O(n) space.
- Use for: connected components, cycle detection in undirected graphs, equivalence class merging.
- Example: Given edges of a graph, determine if two nodes are in the same connected component. Union when you see an edge, Find to check connectivity.
- Leetcode: #200 Number of Islands (alternative to BFS), #684 Redundant Connection, #128 Longest Consecutive Sequence.
- DOD: The parent array and rank array are contiguous. Path compression makes subsequent Finds nearly O(1) by flattening chains.

**Topological sort** — O(V+E) time, O(V) space. Graph → linear order.
- Use for: dependency resolution, build ordering, course scheduling, detecting cycles in directed graphs.
- Example: Given course prerequisites, find a valid order to take all courses. Kahn's algorithm: repeatedly remove nodes with in-degree 0.
- Leetcode: #207 Course Schedule, #210 Course Schedule II.

**BFS / DFS** — O(V+E) time, O(V) space. Traversal over graphs/trees.
- Use for: shortest path (unweighted), connectivity, tree traversal, flood fill.
- Example: Shortest path in an unweighted maze. BFS from start, expanding level by level. First time you reach the target = shortest path.
- Leetcode: #200 Number of Islands (BFS/DFS flood fill), #102 Binary Tree Level Order Traversal, #133 Clone Graph.
- DOD: Store the graph as CSR (Compressed Sparse Row) — one contiguous array of edges, one array of offsets per node. Much better cache behavior than `Vec<Vec<NodeId>>`.

**Quickselect** — O(n) average time, O(1) space. In-place partitioning.
- Use for: finding the Kth largest/smallest element without fully sorting.
- Leetcode: #215 Kth Largest Element in an Array.

**Interval scheduling** — O(n log n) sort + O(n) sweep.
- Use for: meeting rooms, interval merging, non-overlapping intervals.
- Example: Given meeting intervals `[(start, end), ...]`, find the minimum number of rooms needed. Sort by start time, use a min-heap of end times.
- Leetcode: #56 Merge Intervals, #252/253 Meeting Rooms I/II, #435 Non-overlapping Intervals.

### Tier 3 — Pointer-heavy or random access (use when necessary)

These have inherently random access patterns or pointer-chasing. Still the right tool when the problem demands them — but consider array-backed alternatives first.

**Hash map / hash set** — O(1) amortized lookup. Random access into buckets.
- When necessary: frequency counting, deduplication, two-sum lookup, grouping by key.
- Array-backed alternative: sorted array + binary search when data is static. Open-addressing flat hash map (Robin Hood, Swiss Table) over chained buckets for better cache behavior.
- Leetcode: #1 Two Sum, #49 Group Anagrams, #128 Longest Consecutive Sequence.
- DOD: If the key space is small and known, use a direct-indexed array instead (`counts[key]`). If you must hash, prefer open-addressing (all entries in one contiguous array) over chaining (each bucket is a separate allocation).

**Trees (BST, trie, segment tree)** — O(log n) per operation. Pointer-chasing per level.
- When necessary: ordered data with dynamic insertions, prefix search, range queries with updates.
- Array-backed alternative: BIT/Fenwick tree (flat array, O(log n), cache-friendlier). Flat segment tree (2N array). Sorted array for static data.
- Leetcode: #208 Implement Trie, #307 Range Sum Query Mutable (segment tree/BIT).
- DOD: Array-backed trees are dramatically better than pointer-based. A Fenwick tree for range queries is just an array with clever indexing — no nodes, no pointers.

**Linked list** — O(1) insert/delete at known position. Worst-case cache behavior.
- When necessary: LRU cache eviction list, undo history with frequent middle insertions.
- Array-backed alternative: `Vec<T>` with index-based "pointers" (DOD arena). Almost always better. A doubly-linked list backed by an arena of `struct { value: T, prev: u32, next: u32 }` stored contiguously gets O(1) operations without the cache penalty.
- Leetcode: #146 LRU Cache, #206 Reverse Linked List.

**Graph algorithms (general)** — Inherently random access across edges.
- When necessary: shortest path (weighted), network flow, matching.
- Array-backed alternative: CSR (Compressed Sparse Row) for contiguous edge storage. Adjacency list as `Vec<(NodeId, Weight)>` per node, pre-sorted by node for locality.
- Leetcode: #743 Network Delay Time (Dijkstra), #207 Course Schedule (topo sort is better here).

**Backtracking / recursion** — Unpredictable stack depth, branching access patterns.
- When necessary: constraint satisfaction, N-Queens, Sudoku solving, generating all permutations.
- Array-backed alternative: convert to iterative with an explicit stack (`Vec<State>`) when possible. Limits stack depth and gives you cache-friendly state storage.
- Leetcode: #46 Permutations, #51 N-Queens, #79 Word Search.

**DP (top-down memoized)** — Random access to memo table.
- When necessary: when the dependency graph is complex/irregular and you can't easily determine fill order.
- Array-backed alternative: bottom-up tabulation (Tier 2) whenever the dependency order is known. Convert by determining which subproblems are needed and filling them in order.
- Leetcode: #139 Word Break (top-down natural, but bottom-up works), #312 Burst Balloons.

---

## 3. Worked Examples

### Example A: Build a simple HTTP request router

**Problem:** Given incoming HTTP requests, route them to handler functions based on URL path and method.

**Architectural mapping:**
- Primary: **Pipe and Filter** — request bytes flow through stages: `parse_request → match_route → execute_handler → serialize_response`.
- Secondary: **Finite State Machine** — the HTTP parser itself is a state machine over the byte stream (states: parsing method, parsing path, parsing headers, parsing body).
- Secondary: **Index** — the route table is a precomputed lookup structure (trie or hash map of paths → handlers).

**Algorithmic decomposition:**
- HTTP parsing: **Linear scan** (Tier 1) — single pass over the byte buffer, O(n).
- Route matching: **Trie lookup** (Tier 3, but built once at startup) or **hash map** (Tier 3) for exact paths. If routes have parameters (`/users/:id`), a trie is necessary.
- Handler dispatch: **Match/switch** on the route enum — O(1).

**Pseudocode flows into:** `router.pseudocode` with three sections: parse, match, dispatch.

### Example B: Particle physics simulation

**Problem:** Simulate 100,000 particles with position, velocity, mass. Apply gravity, collision detection, position update each frame.

**Architectural mapping:**
- Primary: **Entity-Component-System** — particles are entities, `Position`, `Velocity`, `Mass` are components stored SoA.
- Secondary: **Game Loop** — fixed timestep: `compute_forces → integrate_velocity → update_positions → detect_collisions` each tick.
- Secondary: **Index** — spatial index (grid or BVH) for collision detection, rebuilt each frame.

**Algorithmic decomposition:**
- Force computation: **Linear scan** (Tier 1) — iterate all pairs or use spatial index to reduce to near-neighbors.
- Integration: **Linear scan** (Tier 1) — `vel += force/mass * dt; pos += vel * dt` over contiguous SoA arrays. Autovectorizes.
- Collision detection: **Spatial hash grid** — cells in a flat array indexed by `(x/cell_size, y/cell_size)`. Check only adjacent cells. O(n) expected.
- Collision response: **Two pointers** (Tier 1) per pair within a cell.

**Pseudocode flows into:** `physics_step.pseudocode` with four groups: forces, integrate, detect, resolve.

### Example C: Text editor undo system

**Problem:** Support undo/redo for text editing operations.

**Architectural mapping:**
- Primary: **Undo** — command stack of `(do, undo)` pairs.
- Secondary: **Event Sourcing** — the edit history IS the document (current state = fold over all edits from empty).

**Algorithmic decomposition:**
- Applying an edit: **Direct array operation** (Tier 1) — insert/delete bytes at a position in a gap buffer or rope.
- Undo: **Stack pop** (Tier 2) — pop the last command, apply its inverse.
- Finding the edit position: **Binary search** (Tier 2) if using a piece table; direct index if gap buffer.

---

## Output

After both lenses, you should have:
- 1–3 architectural patterns with justification
- 1–3 algorithmic subproblems with complexities and tiers
- A clear mapping: problem → architectural patterns → algorithmic subproblems

This feeds directly into the [pseudocode step](pseudocode.md).
