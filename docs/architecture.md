# Architecture

Graphomaton processes data through explicit boundaries:

```text
JSON / YAML / Ruby builder
          ↓
immutable State, Transition, and Label records
          ↓
validation profiles and revision-cached graph analysis
          ↓
exporter capability and semantic-loss checks
          ↓
layout → SVG scene, or syntax-specific text exporter
          ↓
optional bounded native conversion to PNG, PDF, or WebP
```

The public builder mutates the graph only through validated methods and increments
`revision` after every effective change. Analysis indexes and layouts are rebuilt
only when the revision changes. Exporters consume immutable record snapshots; the
legacy `states` and `transitions` readers expose frozen compatibility hashes.

SVG is the native visual format. Raster and PDF exporters keep SVG logical
coordinates stable and adjust only output pixel dimensions. DOT, Mermaid, and
PlantUML allocate internal identifiers independently from labels. Every exporter
declares its capabilities so unsupported semantics can be diagnosed or rejected.

External processes run in their own process group with a timeout and stdout/stderr
limits. File output uses a same-directory temporary file and atomic rename.
