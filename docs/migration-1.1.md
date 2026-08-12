# Migrating to 1.1

Builder methods now return the graph, enabling chaining. Duplicate `add_state`
calls raise; use `upsert_state` for replacement. Public `states` and `transitions`
are frozen compatibility snapshots, so mutations must use update/remove methods.

Input schema keys are strict by default and YAML aliases are disabled. Pass
`strict_schema: false` only while migrating legacy documents, and enable aliases
only for trusted YAML.

The CLI validates references by default, rejects options unsupported by the
selected format, and assigns distinct exit statuses. Use `--no-validate` only for
intentional partial diagrams.

Semantic loss is reported for exporters that cannot preserve requested metadata.
Use `strict_semantics: true` or `--strict-semantics` when silent degradation is not
acceptable.
