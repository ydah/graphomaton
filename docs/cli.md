# Command-line reference

`graphomaton render INPUT OUTPUT` is the explicit form of the compatible
`graphomaton INPUT OUTPUT` command. Use `-` for stdin or stdout; stdout requires
`--format`. Rendering validates references by default.

`graphomaton validate INPUT --diagnostics json` validates references, hierarchy,
FSM warnings, and DFA constraints without writing a diagram. Add
`--fail-on-warning` for CI. `graphomaton list` reports formats, layouts, themes,
and converters; `doctor` reports the Ruby version and native renderer status.

Configuration resolution is defaults, `.graphomaton.yml`, environment, then CLI.
`GRAPHOMATON_CONFIG` selects another config. Supported scalar environment values
are `GRAPHOMATON_FORMAT`, `GRAPHOMATON_THEME`, `GRAPHOMATON_LAYOUT`,
`GRAPHOMATON_WIDTH`, and `GRAPHOMATON_HEIGHT`.

Exit statuses are stable: 0 success, 2 usage, 3 input, 4 validation, 5 layout, 6
export/conversion, and 7 security policy. Normal failures omit backtraces; pass
`--debug` while investigating.

Generate integration files with `graphomaton completion bash|zsh|fish` and
`graphomaton man`.
