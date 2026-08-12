# Change log

## Unreleased

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

## 1.0.0 (2025-12-23)

- Add support multiple style outputs, including .dot, mermaid, and .plantuml formats.
- Improve output format for SVG files.

## 0.1.1 (2025-08-26)

Fix gemspec dependency declaration for 'rexml'.

## 0.1.0 (2025-08-26)

- Initial release
