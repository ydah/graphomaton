# Exporter capabilities

| Feature | SVG/PNG/PDF/WebP | DOT | Mermaid | PlantUML |
| --- | --- | --- | --- | --- |
| styles and line styles | yes | partial | partial | partial |
| URL and tooltip | yes | yes | no | no |
| visual groups | yes | yes | partial | partial |
| hierarchy and pseudostates | display | partial | yes | yes |
| edge bundles | yes | no | no | no |

Use `semantic_diagnostics(format)` to inspect loss, `strict_semantics: true` to
reject it, and `render_result` to obtain output, diagnostics, bounds, and resolved
SVG layout together.

`group` is a visual cluster. `parent` is a semantic hierarchy relationship. They
cannot be assigned to the same state. Graph analysis follows transitions and does
not infer statechart execution semantics from visual groups.
