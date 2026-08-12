# Custom exporters

Applications can register an exporter class with a canonical format name, aliases,
filename extensions, binary mode, and the semantics it preserves:

```ruby
class TextExporter
  def initialize(graph)
    @graph = graph
  end

  def export(width, height, prefix: 'graph')
    "#{prefix}: #{@graph.state_records.size} states on #{width}x#{height}\n"
  end
end

Graphomaton.register_exporter(
  :text_graph,
  aliases: %i[tg],
  extensions: %w[textgraph tg],
  capabilities: %i[group],
  exporter: TextExporter
)

graph.render(format: :tg, prefix: 'machine')
```

An exporter class must accept the graph in `initialize` and implement
`export(width, height, **options)`. A loader block can be used instead of the
`exporter:` argument to defer loading optional dependencies. Registration rejects
names, aliases, and extensions that another exporter already owns.

Capability omissions are reported by `semantic_diagnostics` and rejected when
`strict_semantics: true` is used. Set `binary: true` when output must be written in
binary mode. A temporary registration can be removed with
`Graphomaton::EXPORTERS.unregister(:text_graph)`.
