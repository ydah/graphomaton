# Performance and limits

Input defaults are 10 MiB, 10,000 states, 100,000 transitions, metadata depth 64,
and hierarchy depth 64. Canvas area and force iteration counts are bounded. Set
lower limits at untrusted service boundaries.

Graph analysis uses revision-cached incoming, outgoing, and transition-pair
indexes. SCC traversal is iterative. Repeated layouts with identical options are
cached until the graph changes. Force layout switches from exact pair repulsion
to a Barnes-Hut quadtree for large graphs. SVG label collision uses a bounded
uniform-grid index; unusually large boxes fall back to a bounded overflow list.

Run `ruby -Ilib benchmark/render_svg.rb [COUNTS...]` to measure 100, 1,000, and
10,000 transition renders on the local runtime. This benchmark deliberately does
not set a pass/fail time because Ruby, CPU, and renderer configurations vary.

REXML builds the complete SVG DOM in memory. Very large outputs therefore need
memory proportional to generated SVG. Native conversions additionally enforce a
timeout and output byte limit.
