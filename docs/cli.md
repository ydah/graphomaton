# Command-line reference

`graphomaton render INPUT OUTPUT` is the explicit form of the compatible
`graphomaton INPUT OUTPUT` command. Use `-` for stdin or stdout; stdout requires
`--format`. Rendering validates references by default.

`graphomaton validate INPUT --diagnostics json` validates references and hierarchy
without writing a diagram. Select `--profile fsm_semantics`, `--profile dfa`, or
`--profile all` for stronger checks, and add `--fail-on-warning` for CI.
`graphomaton list` reports formats, layouts, themes,
and converters; `doctor` reports the Ruby version plus discovered native renderer
paths and bounded version probes.

Configuration resolution is defaults, `.graphomaton.yml`, environment, then CLI.
`GRAPHOMATON_CONFIG` selects another config. Supported scalar environment values
are `GRAPHOMATON_FORMAT`, `GRAPHOMATON_THEME`, `GRAPHOMATON_LAYOUT`,
`GRAPHOMATON_WIDTH`, and `GRAPHOMATON_HEIGHT`.

Exit statuses are stable: 0 success, 2 usage, 3 input, 4 validation, 5 layout, 6
export/conversion, and 7 security policy. Normal failures omit backtraces; pass
`--debug` while investigating.

Input budgets can be lowered with `--max-input-bytes`, `--max-states`,
`--max-transitions`, `--max-metadata-depth`, `--max-label-length`, and
`--max-group-depth`.

Generate integration files with `graphomaton completion bash|zsh|fish` and
`graphomaton man`.
