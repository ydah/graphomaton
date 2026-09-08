# Changelog

All notable changes to Graphomaton are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project
follows [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [1.2.0] - 2026-09-08

### Added

- Added a public GitHub Pages landing page for the project.
- Added CLI selection for reference, FSM-semantic, DFA, and combined validation
  profiles.
- Added structured mixed epsilon/symbol labels that retain their semantics
  through Hash, JSON, and YAML round trips.

### Changed

- Stronger CLI validation profiles now include reference checks, and exporter
  semantic diagnostics distinguish state and transition tooltips.
- SVG rendering now reuses immutable state snapshots and linear state ordering
  while preserving folded-state kinds and unrelated self-loops.
- Updated the RubyGems trusted-publishing action to 1.4.1.

### Fixed

- Corrected long-word wrapping, explicit-position tracking, duplicate SVG IDs,
  numeric-root style scoping, auto-sized bounds, and stale clipping diagnostics.
- Enforced final SVG and scaled PNG dimension limits before conversion, including
  overflow and non-real numeric inputs.
- Made metadata-depth checks independent of Hash insertion order and rejected
  boolean state identifiers consistently at input boundaries.
- Preserved option-dependent tooltip semantics in strict rendering and retained
  epsilon meaning in array transition labels.
- Made `--no-clobber` atomic, including theme-gallery output races and friendly
  CLI failures.

### Security

- Rejected escaped, comment-obfuscated, and alternate CSS resource functions in
  themes and per-element SVG styles.
- Ensured timed-out Unix process groups are terminated even when the direct
  parent exits first.

## [1.1.0] - 2026-08-13

### Added

- Immutable model records, update/remove APIs, graph revision caches, structured
  labels, diagnostics, validation profiles, exporter capabilities, semantic-loss
  reporting, render results, IO output, and RBS signatures.
- Obstacle-aware curves, adaptive self-loops, spatial label indexing, Barnes-Hut
  force approximation, deterministic force-layout separation, and convergence
  detection.
- CLI commands for validation, discovery, diagnostics, health checks, config
  files, shell completions, and man-page output.
- Bounded stdin/stdout workflows, no-clobber protection, format-specific option
  errors, structured exit statuses, and `--version`.
- Nonce-based CSP support, trusted local asset inlining for self-contained HTML,
  and deterministic HTML asset loading with localized generated UI.
- Restricted gem packaging, gem installation smoke tests, renderer integration
  jobs, release automation, and immutable GitHub Actions pins.

### Changed

- Curved and orthogonal edges are routed from geometry instead of insertion
  order, and SVG viewBoxes include rendered paths, shapes, rotated labels, and
  text content.
- PNG scaling is separated from logical layout and SVG geometry; layout
  diagnostics and metadata survive PNG, PDF, and WebP conversion.
- SCC analysis is iterative and linear-time. Fixed manual positions remain clear
  of automatic layouts, and dense graphs receive adaptive spacing.
- Structured transition labels and format-independent pseudostate kinds are kept
  in the model, while custom exporter registration now produces renderable
  exporters and rejects ambiguous schema aliases.
- HTML pan/zoom controls are more accessible, and text exporters terminate
  output with a newline after normalizing CR/LF label boundaries.

### Fixed

- Corrected force-layout attraction direction, boundary clamping, and analysis
  of undefined transition endpoints.
- Isolated states are declared in DOT, Mermaid, and PlantUML output.
- DOT, Mermaid, PlantUML, and Graphviz layout identifiers are collision-free,
  including reserved names, hostile text, mixed-type model IDs, and groups.
- SVG parallel-transition merging preserves presentation metadata and uses
  tuple endpoint keys; edge endpoints now respect ellipse, diamond, bar, and
  rounded-rectangle boundaries.
- Input validation now rejects duplicate states, malformed transition tuples,
  conflicting initial states, invalid state hierarchies, ignored value types,
  and non-finite rendering numbers.
- Partial state upserts preserve omitted coordinates and effective no-op updates
  do not advance the graph revision.

### Security

- Added URL, HTML JavaScript, theme, and SVG style policies, including safe
  handling of JavaScript strings, trusted local assets, Windows asset paths, and
  unsafe URL schemes; Mermaid.js is pinned to 10.9.8.
- External processes are bounded by timeout and stdout/stderr limits, with
  portable executable discovery and process termination on Windows.
- JSON and YAML input, state and transition counts, metadata depth, label size,
  hierarchy depth, and converter resources are bounded.
- Exported files are written atomically, and embedded scripts enforce size,
  encoding, and digest checks.

## [1.0.0] - 2025-12-23

- Add support for multiple output styles, including DOT, Mermaid, and PlantUML.
- Improve SVG output formatting.

## [0.1.1] - 2025-08-26

- Fix the gemspec dependency declaration for `rexml`.

## [0.1.0] - 2025-08-26

- Initial release
