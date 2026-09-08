# Input schema version 1

The top-level mapping accepts `version`, `states`, `transitions`, `initial` (or
`initial_state`), and `final` (or `final_states`). Unknown keys are errors by
default. `version` is optional for compatibility and, when present, must be `1`.

States may be an array or a mapping keyed by state ID. A state mapping accepts
`id`, `name`, `x`, `y`, `label`, `style`, `metadata`, `shape`, `kind`, `initial`,
`final`, and `accepting`. `kind` is `normal`, `choice`, `fork`, or `join`. State IDs
must be unique. `initial` is singular. `metadata.parent`
must name an existing state and may not form a cycle or coexist with a visual
`group`.

Transitions are an array. Each item is either a mapping with `from`, `to`, and
`label`, or a three-element tuple. Mapping options are `style`, `metadata`, and
`line_style`. Reference validation is deferred in the Ruby library and enabled by
default in the CLI.

State and transition `style` and `metadata` values must be mappings. State labels
are scalar display text. Transition labels may be scalar text, a symbol array, or
a structured label with an explicit `type`/`kind`; malformed collections are
rejected instead of being stringified or ignored. Ruby label arrays containing
`:epsilon` preserve both meanings as a structured `alternatives` label.

YAML aliases are disabled. Parsing limits input bytes, state and transition
counts, label bytes, metadata depth, and hierarchy depth. Callers handling
untrusted data should lower the defaults for their service budget.
