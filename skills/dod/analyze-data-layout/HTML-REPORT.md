# HTML Report Format

The data layout analysis is rendered as a single self-contained HTML file in the OS temp directory. Tailwind and Mermaid both come from CDNs. Mermaid handles relationship graphs; hand-built divs and inline SVG handle memory layout diagrams and heatmaps — those need pixel-level control Mermaid can't give.

## Scaffold

```html
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <title>Data Layout Analysis — {{module name}}</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <script type="module">
      import mermaid from "https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.esm.min.mjs";
      mermaid.initialize({ startOnLoad: true, theme: "neutral", securityLevel: "loose" });
    </script>
    <style>
      .hot { background: #fef2f2; border-left: 3px solid #dc2626; }
      .cold { background: #f0f9ff; border-left: 3px solid #3b82f6; }
      .padding { background: #fef3c7; opacity: 0.6; }
      .cache-line { border: 1px dashed #94a3b8; }
      .overlap { stroke: #f59e0b; stroke-width: 2px; }
    </style>
  </head>
  <body class="bg-stone-50 text-slate-900 font-sans">
    <main class="max-w-6xl mx-auto px-6 py-12 space-y-12">
      <header>...</header>
      <section id="type-map">...</section>
      <section id="overlap-graph">...</section>
      <section id="access-heatmap">...</section>
      <section id="proposals">...</section>
      <section id="impact">...</section>
      <section id="level-3">...</section>
      <section id="top-recommendation">...</section>
    </main>
  </body>
</html>
```

## Header

Module name, language, date, total types analyzed, total memory footprint. Compact legend: red-left-border = hot field, blue-left-border = cold field, yellow = padding waste, dashed = cache line boundary. No introduction paragraph — straight into the data.

## Section 1: Type Map

One card per type. Each card shows:

### Memory layout diagram (hand-built divs)

A horizontal bar representing the struct's memory layout. Each field is a colored block proportional to its byte size. Padding bytes shown as yellow blocks between fields. Cache line boundaries as dashed vertical lines.

```html
<div class="flex items-stretch h-12 rounded border border-slate-300 overflow-hidden font-mono text-xs">
  <!-- field: pos [f32; 3] = 12 bytes -->
  <div class="hot flex items-center justify-center" style="width: {{pct}}%">
    pos: 12B
  </div>
  <!-- padding: 0 bytes (aligned) -->
  <!-- field: color u32 = 4 bytes -->
  <div class="cold flex items-center justify-center" style="width: {{pct}}%">
    color: 4B
  </div>
  <!-- field: alive bool = 1 byte -->
  <div class="cold flex items-center justify-center" style="width: {{pct}}%">
    alive: 1B
  </div>
  <!-- padding: 3 bytes -->
  <div class="padding flex items-center justify-center" style="width: {{pct}}%">
    pad: 3B
  </div>
</div>
```

### Stats row

`font-mono text-sm` row below the bar:
- Total size: `N bytes`
- Padding: `N bytes (M%)`
- Elements per cache line: `N`
- Hot fields: `N/M`

## Section 2: Semantic Overlap Graph

Mermaid graph showing type relationships. Overlapping types connected with amber arrows labeled with the overlap kind (subset, convertible, shared-fields).

```html
<div class="rounded-lg border border-slate-200 bg-white p-4">
  <pre class="mermaid">
    graph LR
      Point["Point(x: u32, y: u32)<br/>8B"]
      Rect["Rect(x: u32, y: u32, w: u32, h: u32)<br/>16B"]
      Polygon["Polygon(p1: Point, p2: Point)<br/>16B"]
      Point -->|"subset"| Rect
      Point -->|"contained"| Polygon
      Rect ---|"same data as"| Polygon
      classDef overlap stroke:#f59e0b,stroke-width:2px;
      class Point,Rect,Polygon overlap
  </pre>
</div>
```

Below the graph: one sentence naming the proposed canonical type and why.

## Section 3: Access Pattern Heatmap

A table. Rows = functions. Columns = fields (across all types in scope). Cells colored by access intensity:

- Dark red: hot path, read+write
- Light red: hot path, read-only
- Light blue: cold path
- Empty: not accessed

```html
<table class="w-full text-xs font-mono border-collapse">
  <thead>
    <tr>
      <th class="text-left p-2">Function</th>
      <th class="p-2 rotate-45">pos.x</th>
      <th class="p-2 rotate-45">pos.y</th>
      <th class="p-2 rotate-45">vel.x</th>
      <!-- ... -->
    </tr>
  </thead>
  <tbody>
    <tr>
      <td class="p-2">update_positions</td>
      <td class="bg-red-600 text-white p-2">RW</td>
      <td class="bg-red-600 text-white p-2">RW</td>
      <td class="bg-red-300 p-2">R</td>
      <!-- ... -->
    </tr>
  </tbody>
</table>
```

This table is the evidence for every AoS/SoA and hot/cold decision. If the table doesn't justify it, the proposal is wrong.

## Section 4: Proposals

One card per type (or type cluster for overlapping types). Each card:

- **Title** — short, names the transform (e.g. "Split Particle into hot SoA + cold side table").
- **Badge row** — restructure level (`Level 1` = slate, `Level 2` = emerald, `Level 3 option` = amber).
- **Before / After** — two columns, side by side:
  - Before: the current struct definition + memory layout bar
  - After: the proposed layout + memory layout bar
  - Both as code blocks + the visual bar from Section 1
- **What changes** — one sentence.
- **Affected functions** — monospaced list with brief note on how each changes.
- **Wins** — bullets, max 6 words each. e.g. "3x elements per cache line", "padding eliminated", "pos+vel contiguous for SIMD".

No paragraphs. If the diagram needs a paragraph, redraw it.

## Section 5: Estimated Impact

Summary table:

| Metric | Before | After | Delta |
|--------|--------|-------|-------|
| Total memory footprint | X bytes | Y bytes | -Z% |
| Padding waste | X bytes | Y bytes | -Z% |
| Cache lines per iteration (hot loop) | X | Y | -Z% |
| Elements per cache line (hot type) | X | Y | +Z% |
| Vectorizable loops | X/Y | X+N/Y | +N |

## Section 6: Level 3 Option

A collapsible `<details>` section showing the flat-buffer alternative. Not recommended by default — shown so the user knows what maximum DOD looks like.

```html
<details class="rounded-lg border border-amber-200 bg-amber-50 p-4">
  <summary class="font-semibold cursor-pointer">Level 3: Flat buffer layout (advanced)</summary>
  <div class="mt-4 space-y-4">
    <!-- Flat buffer layout diagram -->
    <!-- Index scheme explanation -->
    <!-- API surface change description -->
  </div>
</details>
```

## Section 7: Top Recommendation

One larger card. Which transform to apply first, one sentence why, anchor link to its card.

## Style Guidance

- Lean technical, not dashboard. Generous whitespace. Monospace for all data.
- Colors: red for hot, blue for cold, yellow/amber for padding/waste, emerald for proposed improvements, slate for neutral.
- Memory layout bars should be ~full width, ~48px tall. Before/after sit side by side.
- The heatmap carries the analytical weight. Make it scannable.
- The only scripts are Tailwind CDN and Mermaid ESM. No interactivity beyond Mermaid rendering and the Level 3 `<details>` toggle.

## Tone

Technical, concise. Use [LANGUAGE.md](LANGUAGE.md) vocabulary exactly:
- **type map**, **semantic overlap**, **canonical type**, **access pattern**, **hot field**, **cold field**, **cache line utilization**, **padding**, **side table**.
- **AoS**, **SoA**, **hybrid**, **flat buffer**.
- **Level 1/2/3**.

**Never substitute:** layout (for type map), redundancy (for semantic overlap), base type (for canonical type), usage (for access pattern).

Numbers speak. Every proposal backed by the heatmap. Every win quantified where possible.
