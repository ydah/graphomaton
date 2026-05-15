# Graphomaton [![Gem Version](https://badge.fury.io/rb/graphomaton.svg?icon=si%3Arubygems)](https://badge.fury.io/rb/graphomaton) [![CI](https://github.com/ydah/graphomaton/actions/workflows/ci.yml/badge.svg)](https://github.com/ydah/graphomaton/actions/workflows/ci.yml)

A small Ruby library for generating finite state machine and automaton diagrams as SVG, PNG, PDF, WebP, HTML with Mermaid.js, GraphViz DOT, and PlantUML.

![Image](https://github.com/user-attachments/assets/6907869c-1077-4a73-8394-4117f25adc17)

## Installation

```ruby
gem 'graphomaton'
```

```bash
bundle install
# or
gem install graphomaton
```

## Quick start

```ruby
require 'graphomaton'

automaton = Graphomaton.new
automaton.add_state('q0', label: 'Start')
automaton.add_state('q1')
automaton.add_state('q2', label: 'Accept')
automaton.set_initial('q0')
automaton.add_final('q2')

automaton.add_transition('q0', 'q1', 'a')
automaton.add_transition('q1', 'q2', 'b')
automaton.add_transition('q0', 'q2', :epsilon)

automaton.save_svg('diagram.svg')
automaton.save_html('diagram.html')
automaton.save_dot('diagram.dot')
automaton.save_plantuml('diagram.puml')
```

Use `render` and `save` when the format is selected dynamically:

```ruby
automaton.render(format: :svg, width: 800, height: 600)
automaton.save('diagram.svg', format: :svg, width: 800, height: 600)
```

Validate and inspect the automaton before rendering:

```ruby
automaton.validate!
automaton.layout_warnings(800, 600)
automaton.reachable_states
automaton.dead_states
automaton.trap_states
```

## Loading data

Build an automaton from Hash, JSON, or YAML:

```ruby
automaton = Graphomaton.from_hash(
  states: [
    { id: 'q0', label: 'Start', initial: true },
    { id: 'q1', final: true }
  ],
  transitions: [
    { from: 'q0', to: 'q1', label: 'a', line_style: 'dashed' }
  ]
)

Graphomaton.from_json(File.read('automaton.json'))
Graphomaton.from_yaml(File.read('automaton.yml'))
```

## Examples

### Styled SVG with metadata

```ruby
automaton = Graphomaton.new
automaton.add_state(
  'idle',
  label: 'Idle',
  metadata: { tooltip: 'Waiting for work', group: 'runtime', icon: 'I' }
)
automaton.add_state(
  'running',
  label: 'Running',
  metadata: { tooltip: 'Processing job', group: 'runtime', url: 'https://example.com/runbook' }
)
automaton.add_state('failed', label: 'Failed', style: { fill: '#fee2e2', stroke: '#dc2626' })

automaton.set_initial('idle')
automaton.add_transition('idle', 'running', 'start', metadata: { bundle: 'happy-path' })
automaton.add_transition('running', 'idle', 'finish', metadata: { bundle: 'happy-path' })
automaton.add_transition('running', 'failed', 'error', line_style: :dashed)

automaton.save_svg(
  'runtime.svg',
  900,
  500,
  layout: :layered,
  direction: :lr,
  theme: :ocean,
  edge_style: :spline,
  label_tooltips: true,
  html_tooltips: true
)
```

### Manual coordinates

```ruby
automaton = Graphomaton.new
automaton.add_state('north', 300, 80)
automaton.add_state('east', 520, 260)
automaton.add_state('south', 300, 440)
automaton.add_state('west', 80, 260)

automaton.add_transition('north', 'east', 'turn')
automaton.add_transition('east', 'south', 'turn')
automaton.add_transition('south', 'west', 'turn')
automaton.add_transition('west', 'north', 'turn')

automaton.save_svg('manual.svg', 600, 520, layout: :manual, fit: :contain)
```

### Folded groups

```ruby
automaton = Graphomaton.new
automaton.add_state('parse', metadata: { group: 'frontend' })
automaton.add_state('validate', metadata: { group: 'frontend' })
automaton.add_state('execute', metadata: { group: 'backend' })
automaton.add_state('persist', metadata: { group: 'backend' })

automaton.add_transition('parse', 'validate', 'ok')
automaton.add_transition('validate', 'execute', 'accepted')
automaton.add_transition('execute', 'persist', 'done')

automaton.save_svg('folded.svg', layout: :layered, fold_groups: true)
```

### YAML input for the CLI

```yaml
states:
  - id: idle
    label: Idle
    initial: true
    metadata:
      group: runtime
      tooltip: Waiting for work
  - id: running
    label: Running
    metadata:
      group: runtime
  - id: done
    final: true
transitions:
  - from: idle
    to: running
    label: start
  - from: running
    to: done
    label: finish
    line_style: dashed
```

```bash
graphomaton --input automaton.yml --output runtime.svg --layout layered --direction lr --theme ocean
```

### Export several formats

```ruby
outputs = {
  svg: 'diagram.svg',
  html: 'diagram.html',
  dot: 'diagram.dot',
  plantuml: 'diagram.puml'
}

outputs.each do |format, path|
  automaton.save(path, format: format)
end
```

## CLI

```bash
graphomaton --input automaton.yml --output diagram.svg
graphomaton --input automaton.yml --output diagram.svg --validate --layout-warnings
graphomaton --input automaton.json --output diagram.png --format png --theme dark --scale 2
graphomaton --input automaton.yml --output diagram.html --title "Automaton" --show-source --pan-zoom
graphomaton --input automaton.yml --output diagram.dot --rank-constraints
```

Common SVG options:

```bash
graphomaton --input automaton.yml --output diagram.svg --layout layered --direction lr
graphomaton --input automaton.yml --output diagram.svg --layout force --node-spacing 140 --force-iterations 80 --layout-seed 42
graphomaton --input automaton.yml --output diagram.svg --layout graphviz --graphviz-command dot
graphomaton --input automaton.yml --output diagram.svg --responsive --fit cover --auto-size
graphomaton --input automaton.yml --output diagram.svg --state-shape ellipse --edge-style spline --arrow-shape vee
graphomaton --input automaton.yml --output diagram.svg --wrap-labels --state-wrap --label-tooltips --html-tooltips
graphomaton --input automaton.yml --output diagram.svg --highlight-unreachable --unreachable-zone right --highlight-dead-states
graphomaton --input automaton.yml --output diagram.svg --scc-groups --fold-groups
graphomaton --input automaton.yml --output diagram.svg --theme-file theme.yml
```

Theme utilities:

```bash
graphomaton --list-themes
graphomaton --theme-gallery --output theme_gallery.html
graphomaton --theme-gallery --theme-gallery-animated --theme-file theme.yml --output theme_gallery.html
```

## Themes

Native SVG and SVG-backed outputs support named or custom themes:

```ruby
automaton.save_svg('diagram.svg', theme: :dark)
automaton.save_png('diagram.png', theme: :forest)
automaton.save_svg('diagram.svg', theme: :auto) # follows prefers-color-scheme

theme = Graphomaton.theme_from_yaml(File.read('theme.yml'))
automaton.save_svg('diagram.svg', theme: theme)

Graphomaton::Theme.save_gallery_html('theme_gallery.html')
```

Built-in themes:

```text
light, dark, forest, ocean, high_contrast, color_blind, print, minimal, academic, presentation, auto
```

## SVG output

SVG is Graphomaton's native renderer. It supports multiple layouts, styling options, metadata-driven annotations, and converter-backed raster/vector outputs.

### Layouts

```ruby
automaton.save_svg('diagram.svg', 800, 600, layout: :linear, direction: :lr)
automaton.save_svg('diagram.svg', 800, 600, layout: :circle)
automaton.save_svg('diagram.svg', 800, 600, layout: :grid)
automaton.save_svg('diagram.svg', 800, 600, layout: :layered)
automaton.save_svg('diagram.svg', 800, 600, layout: :bfs)
automaton.save_svg('diagram.svg', 800, 600, layout: :force, layout_seed: 42)
automaton.save_svg('diagram.svg', 800, 600, layout: :graphviz, graphviz_command: 'dot')
automaton.save_svg('diagram.svg', 800, 600, layout: :manual)
```

Layout notes:

- `direction` accepts `:lr`, `:tb`, `:rl`, and `:bt`.
- `layout` accepts `:linear`, `:circle`, `:grid`, `:layered`, `:bfs`, `:force`, `:graphviz`, `:dot`, and `:manual`.
- `:layered` and `:bfs` use deterministic barycenter ordering to reduce crossings.
- `:force` accepts `padding`, `node_spacing`, `rank_spacing`, `force_iterations`, and `layout_seed`.
- `:graphviz` and `:dot` call `dot -Tplain` through `graphviz_command:` and normalize returned node coordinates into the SVG canvas.
- `preserve_manual_positions: false` lets automatic layouts reposition states with explicit coordinates.
- `fit: :contain` fits positions into the canvas; `fit: :cover` stretches positions to use the canvas.
- `auto_size: true` expands the SVG viewport around rendered positions.

### Styling and labels

```ruby
automaton.save_svg('diagram.svg', state_shape: :ellipse)
automaton.save_svg('diagram.svg', state_stroke_width: 3, transition_stroke_width: 2)
automaton.save_svg('diagram.svg', edge_style: :orthogonal)
automaton.save_svg('diagram.svg', arrow_shape: :vee, arrow_size: 14)
automaton.save_svg('diagram.svg', state_effect: :shadow)
automaton.save_svg('diagram.svg', font_family: '"Noto Sans JP", sans-serif', state_font_weight: 700)

automaton.save_svg('diagram.svg', wrap: true, max_transition_label_width: 120)
automaton.save_svg('diagram.svg', state_wrap: true, max_state_label_width: 120)
automaton.save_svg('diagram.svg', label_tooltips: true, html_tooltips: true)
automaton.save_svg('diagram.svg', rotate_labels: true)
automaton.save_svg('diagram.svg', label_background: false)
automaton.save_svg('diagram.svg', label_padding: 16, label_radius: 8, label_border: true)
```

Other SVG options:

- `svg_id:` sets a stable SVG root and marker ID prefix.
- `css_variables: true` emits theme values as CSS variables.
- `embed_styles: false` skips the embedded style block.
- `xml_declaration: true`, `pretty: true`, and `minify: true` control serialization.
- `initial_arrow_length`, `initial_arrow_label`, `final_arrow_length`, `final_arrow_label`, and `show_final_arrows` control native start/end arrows.

### Metadata

State and transition metadata can enrich generated diagrams without changing state IDs:

```ruby
automaton.add_state(
  'q0',
  label: 'Start',
  metadata: {
    tooltip: 'Entry point',
    url: 'https://example.com',
    group: 'main',
    icon: 'S',
    mermaid: { shape: 'choice' }
  }
)

automaton.add_transition(
  'q0',
  'q1',
  'next',
  metadata: {
    tooltip: 'Main path',
    bundle: 'primary'
  }
)
```

Metadata behavior:

- `label` changes the display name while preserving the state ID for transitions.
- `tooltip` or `description` becomes SVG tooltip text.
- `url` or `href` creates SVG links and DOT URL attributes.
- `group` or `cluster` renders SVG background groups, Mermaid/PlantUML composite states, and DOT clusters.
- `icon` renders a compact SVG icon label inside the state.
- `bundle` routes native SVG edges through a shared control point and emits `data-bundle`.
- `choice`, `fork`, and `join` pseudostates can be requested with `svg`, `dot`, `mermaid`, `plantuml`, or compatible shorthand metadata.
- `fold_groups: true` collapses grouped SVG states into compound nodes, hides internal transitions, and rewrites external transitions to the folded node.
- `scc_groups: true` renders SVG groups around strongly connected components.

## Output formats

| Format | Method | Notes |
| --- | --- | --- |
| SVG | `save_svg` | Native renderer. |
| PNG | `save_png` | Converts native SVG. Requires `rsvg-convert`, `magick`, or `convert`. |
| PDF | `save_pdf` | Converts native SVG. Requires `rsvg-convert`, `magick`, or `convert`. |
| WebP | `save_webp` | Converts native SVG. Requires ImageMagick `magick` or `convert`. |
| HTML | `save_html` | Mermaid.js state diagram in an HTML page. |
| DOT | `save_dot` | GraphViz DOT source. |
| PlantUML | `save_plantuml` | PlantUML state diagram source. |

### Converter-backed formats

```ruby
automaton.save_png('diagram.png', 800, 600, scale: 2.0, converter: :magick)
automaton.save_pdf('diagram.pdf', 800, 600, converter: :magick)
automaton.save_webp('diagram.webp', 800, 600, converter: :magick)

Graphomaton.png_available?(converter: :auto)
Graphomaton.pdf_available?(converter: :auto)
Graphomaton.webp_available?(converter: :auto)
```

### HTML with Mermaid.js

```ruby
automaton.save_html('diagram.html')
automaton.save_html('diagram.html', show_source: true)
automaton.save_html('diagram.html', theme: :auto)
automaton.save_html('diagram.html', cdn: './mermaid.min.js', inline_mermaid: true)
automaton.save_html('diagram.html', pan_zoom: true)
automaton.save_html('diagram.html', mathjax: true)
automaton.save_html('diagram.html', notes: true, class_defs: true)
```

By default, HTML output uses Mermaid.js from CDN. Use a local `cdn:` path with `inline_mermaid: true` for offline output.

### GraphViz DOT

```ruby
automaton.save_dot('diagram.dot')
automaton.save_dot('diagram.dot', theme: :ocean)
automaton.save_dot('diagram.dot', rank_constraints: true)
```

```bash
dot -Tpng diagram.dot -o diagram.png
dot -Tsvg diagram.dot -o diagram.svg
dot -Tpdf diagram.dot -o diagram.pdf
neato -Tsvg diagram.dot -o diagram-neato.svg
sfdp -Tsvg diagram.dot -o diagram-sfdp.svg
```

Use `dot` for ranked state-machine layouts. Use `neato` or `sfdp` for dense graphs where free spreading is preferred.

### PlantUML

```ruby
automaton.save_plantuml('diagram.puml')
automaton.save_plantuml('diagram.puml', theme: :forest)
automaton.save_plantuml('diagram.puml', notes: true)
```

```bash
java -jar plantuml.jar diagram.puml
curl -X POST --data-binary @diagram.puml https://www.plantuml.com/plantuml/png > diagram.png
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/ydah/graphomaton.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Graphomaton project's codebases, issue trackers, chat rooms, and mailing lists is expected to follow the [code of conduct](https://github.com/ydah/graphomaton/blob/main/CODE_OF_CONDUCT.md).
