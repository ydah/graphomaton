# Change log

## Unreleased

## 1.1.0 (2026-08-12)

- Fix force-layout attraction direction, boundary clamping, and undefined endpoint analysis.
- Declare isolated states and allocate collision-free identifiers in DOT, Mermaid, and PlantUML.
- Preserve SVG transition presentation metadata and connect edges to shape-aware boundaries.
- Keep PNG scaling independent from logical layout and SVG geometry.
- Add safe URL, HTML JavaScript, theme, and SVG style policies; pin Mermaid.js 10.9.8.
- Add bounded external process execution with timeout and output limits.
- Validate input state uniqueness, transition tuples, initial states, and state hierarchy.
- Write exported files atomically and terminate text formats with a newline.
- Validate CLI input by default and provide structured exit statuses and `--version`.
- Restrict packaged gem files and add package installation smoke testing.
- Bound JSON and YAML bytes, state counts, transition counts, and converter resources.
- Reject non-finite rendering numbers and keep fixed manual positions clear of automatic layouts.
- Add bounded stdin/stdout CLI workflows, no-clobber protection, and format-specific option errors.
- Make HTML asset loading deterministic, localize generated UI, and improve pan/zoom accessibility.
- Replace recursive SCC analysis with an iterative linear-time implementation.
- Route curved and orthogonal edges from geometry rather than insertion order.
- Size SVG viewBoxes from rendered paths, shapes, rotated labels, and text content.
- Add deterministic force-layout separation and convergence detection.
- Add immutable model records, update/remove APIs, graph revision caches, structured labels, diagnostics, and validation profiles.
- Add exporter capabilities, semantic-loss reporting, render results, IO output, and RBS signatures.
- Add obstacle-aware curves, adaptive self-loops, spatial label indexing, and Barnes-Hut force approximation.
- Add CLI commands for validation, discovery, diagnostics, health checks, config files, completions, and man-page output.
- Add nonce-based CSP support and trusted local asset inlining for self-contained HTML.

## 1.0.0 (2025-12-23)

- Add support multiple style outputs, including .dot, mermaid, and .plantuml formats.
- Improve output format for SVG files.

## 0.1.1 (2025-08-26)

Fix gemspec dependency declaration for 'rexml'.

## 0.1.0 (2025-08-26)

- Initial release
