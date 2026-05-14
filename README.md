# Graphomaton [![Gem Version](https://badge.fury.io/rb/graphomaton.svg?icon=si%3Arubygems)](https://badge.fury.io/rb/graphomaton) [![CI](https://github.com/ydah/graphomaton/actions/workflows/ci.yml/badge.svg)](https://github.com/ydah/graphomaton/actions/workflows/ci.yml)

A tiny Ruby library for generating finite state machine (automaton) diagrams in multiple formats: SVG, PNG, PDF, WebP, HTML (Mermaid.js), GraphViz (DOT), and PlantUML.

![Image](https://github.com/user-attachments/assets/6907869c-1077-4a73-8394-4117f25adc17)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'graphomaton'
```

And then execute:

```bash
bundle install
```

Or install it yourself as:

```bash
gem install graphomaton
```

## Usage

```ruby
require 'graphomaton'

# Create a DFA that accepts strings ending with 'ab'
automaton = Graphomaton.new

# Add states
automaton.add_state('q0')
automaton.add_state('q1')
automaton.add_state('q2')
automaton.add_state('q_named', label: 'Named State', style: { fill: '#fee2e2' }, metadata: { tooltip: 'Shown in SVG' }, shape: :rounded_rect)

# Set initial and final states
automaton.set_initial('q0')
automaton.add_final('q2')

# Add transitions
automaton.add_transition('q0', 'q1', 'a')
automaton.add_transition('q1', 'q2', 'b')
automaton.add_transition('q0', 'q2', ['a', 'b'])
automaton.add_transition('q1', 'q2', ['b', 'a'], sort_labels: true)
automaton.add_transition('q0', 'q1', :epsilon)
automaton.add_transition('q0', 'q2', 'error', line_style: :dashed)
automaton.add_transition('q1', 'q1', 'loop', style: { stroke: '#ef4444' }, metadata: { tooltip: 'Highlighted loop' })
automaton.add_transition('q0', 'q0', 'b')
automaton.add_transition('q1', 'q0', 'a')
automaton.add_transition('q2', 'q0', 'b')
automaton.add_transition('q2', 'q1', 'a')

# Save in different formats
automaton.save_svg('output.svg')              # SVG format
automaton.save_png('output.png')              # PNG format (requires a converter)
automaton.save_pdf('output.pdf')              # PDF format (requires a converter)
automaton.save_webp('output.webp')            # WebP format (requires ImageMagick)
automaton.save_html('output.html')            # HTML with Mermaid.js (requires internet)
automaton.save_dot('output.dot')              # GraphViz DOT format
automaton.save_plantuml('output.puml')        # PlantUML format

# Or use the unified API
automaton.render(format: :svg, width: 800, height: 600)
automaton.save('output.svg', format: :svg, width: 800, height: 600)

# Validate references before rendering if desired
automaton.validate!
automaton.layout_warnings(800, 600)
automaton.live_states
automaton.dead_states
automaton.trap_states
```

`label` is used as the display name in SVG, DOT, Mermaid, and PlantUML while the state ID remains stable for transitions.
State and transition metadata `tooltip`/`description` is used as SVG tooltip text. Metadata `url`/`href` creates clickable SVG links.
Mermaid choice/fork/join pseudostates can be requested with state metadata such as `{ mermaid: { shape: 'choice' } }`, `mermaid_shape`, or `mermaid_type`.

You can also build an automaton from Hash, JSON, or YAML input:

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

### CLI

```bash
graphomaton --input automaton.yml --output diagram.svg
graphomaton --input automaton.yml --output diagram.svg --validate
graphomaton --input automaton.yml --output diagram.svg --layout-warnings
graphomaton --input automaton.json --output diagram.png --format png --theme dark --scale 2 --converter magick
graphomaton --input automaton.yml --output diagram.svg --layout layered --direction lr
graphomaton --input automaton.yml --output diagram.svg --layout force --padding 80 --node-spacing 140 --force-iterations 80 --layout-seed 42
graphomaton --input automaton.yml --output diagram.svg --responsive --state-radius 32 --fit cover --auto-size
graphomaton --input automaton.yml --output diagram.svg --auto-state-radius --min-state-radius 32 --max-state-radius 72
graphomaton --input automaton.yml --output diagram.svg --state-shape ellipse --edge-style orthogonal --arrow-shape vee
graphomaton --input automaton.yml --output diagram.svg --edge-style spline
graphomaton --input automaton.yml --output diagram.svg --state-stroke-width 4 --transition-stroke-width 3 --font-family "Noto Sans" --state-effect shadow
graphomaton --input automaton.yml --output diagram.svg --state-effect pulse
graphomaton --input automaton.yml --output diagram.svg --xml-declaration --pretty
graphomaton --input automaton.yml --output diagram.svg --css-variables --no-embed-styles
graphomaton --input automaton.yml --output diagram.svg --wrap-labels --state-wrap --label-tooltips --html-tooltips --rotate-labels --show-final-arrows
graphomaton --input automaton.yml --output diagram.svg --sort-labels --highlight-transition "q0:q1:a, b" --loop-position right
graphomaton --input automaton.yml --output diagram.svg --label-padding 20 --label-radius 8 --label-border --initial-arrow-label begin --final-arrow-label done
graphomaton --input automaton.yml --output diagram.svg --highlight-unreachable --unreachable-zone right --highlight-dead-states
graphomaton --input automaton.yml --output diagram.svg --no-preserve-manual-positions
graphomaton --input automaton.yml --output diagram.svg --theme-file theme.yml
graphomaton --input automaton.yml --output diagram.html --title "Automaton" --lang en --show-source --pan-zoom --notes --class-defs
graphomaton --input automaton.yml --output diagram.html --cdn ./mermaid.min.js --inline-mermaid
graphomaton --input automaton.yml --output diagram.dot --rank-constraints
```

### Themes

Native SVG and PNG output can be rendered with a named theme:

```ruby
automaton.save_svg('output_dark.svg', theme: :dark)
automaton.save_png('output_forest.png', theme: :forest)
automaton.save_svg('output_auto.svg', theme: :auto) # follows prefers-color-scheme
custom_theme = Graphomaton.theme_from_yaml(File.read('theme.yml'))
automaton.save_svg('output_custom.svg', theme: custom_theme)
Graphomaton::Theme.save_gallery_html('theme_gallery.html')
```

Available themes: `:light`, `:dark`, `:forest`, `:ocean`, `:high_contrast`, `:color_blind`, `:print`, `:minimal`, `:academic`, `:presentation`, `:auto`.

### Output Formats

Graphomaton supports multiple output formats:

#### 1. SVG (Native)
```ruby
automaton.save_svg('diagram.svg', 800, 600, theme: :light)
```
Generates a standalone SVG file with custom rendering.
You can also control layout direction and responsive sizing:

```ruby
automaton.save_svg('diagram.svg', 800, 600, direction: :tb, responsive: true)
automaton.save_svg('diagram.svg', 800, 600, layout: :linear, direction: :lr)
automaton.save_svg('diagram.svg', 800, 600, layout: :circle, direction: :tb)
automaton.save_svg('diagram.svg', 800, 600, layout: :grid, direction: :lr)
automaton.save_svg('diagram.svg', 800, 600, layout: :layered, direction: :lr)
automaton.save_svg('diagram.svg', 800, 600, layout: :bfs, direction: :lr)
automaton.save_svg('diagram.svg', 800, 600, layout: :force, direction: :lr)
automaton.save_svg('diagram.svg', 800, 600, layout: :manual)
automaton.save_svg('diagram.svg', 800, 600, svg_id: 'diagram-main')
automaton.save_svg('diagram.svg', 800, 600, state_stroke_width: 3, transition_stroke_width: 2)
automaton.save_svg('diagram.svg', 800, 600, font_family: '"Noto Sans JP", sans-serif', state_font_weight: 700)
automaton.save_svg(
  'diagram.svg',
  800,
  600,
  layout: :force,
  padding: 80,
  node_spacing: 120,
  rank_spacing: 120,
  force_iterations: 120,
  layout_seed: 42
)
```

`direction` accepts `:lr`, `:tb`, `:rl`, `:bt` for left-right, top-bottom, right-left, and bottom-top layouts.
`initial_position` accepts `:auto` and `:start`. `:start` places the initial state near the start side of the layout.
`final_position` accepts `:auto` and `:end`. `:end` moves final states toward the end side of the layout.
`layout` currently supports `:linear`, `:circle`, `:grid`, `:layered`, `:bfs`, `:force`, `:manual`.
`preserve_manual_positions: false` lets automatic layouts reposition states that were added with explicit coordinates.
`fit: :contain` scales and shifts resolved positions so the graph fits inside the requested canvas.
`fit: :cover` stretches resolved positions to use the full requested canvas.
`svg_id:` sets a stable SVG root ID and marker ID prefix, useful when embedding multiple diagrams.
`auto_size` expands SVG viewport automatically to the rendered positions when set to `true`.
`arrow_size` controls SVG arrowhead size.
`arrow_shape` accepts `:triangle`, `:vee`, and `:stealth`.
`initial_arrow_length` and `initial_arrow_label` control the native SVG initial arrow.
`final_arrow_length` and `final_arrow_label` control optional native SVG final arrows.
`force` accepts optional tuning keys `padding`, `node_spacing`, `rank_spacing`, `force_iterations`, and `layout_seed`.

You can also control label display behavior:

```ruby
automaton.save_svg('diagram.svg', 800, 600, wrap: true, max_transition_label_width: 120)
automaton.save_svg('diagram.svg', 800, 600, sort_labels: true)
automaton.save_svg('diagram.svg', 800, 600, label_tooltips: true)
automaton.save_svg('diagram.svg', 800, 600, html_tooltips: true)
automaton.save_svg('diagram.svg', 800, 600, rotate_labels: true)
automaton.save_svg('diagram.svg', 800, 600, label_background: false)
automaton.save_svg('diagram.svg', 800, 600, label_padding: 16, label_radius: 8, label_border: true)
automaton.save_svg('diagram.svg', 800, 600, highlight_unreachable: true)
automaton.save_svg('diagram.svg', 800, 600, unreachable_zone: :right)
automaton.save_svg('diagram.svg', 800, 600, highlight_dead_states: true)
automaton.save_svg('diagram.svg', 800, 600, highlight_initial_state: true, highlight_final_states: true)
automaton.save_svg('diagram.svg', 800, 600, highlight_transitions: [{ from: 'q0', to: 'q1', label: 'a' }])
automaton.save_svg('diagram.svg', 800, 600, xml_declaration: true)
automaton.save_svg('diagram.svg', 800, 600, css_variables: true)
automaton.save_svg('diagram.svg', 800, 600, embed_styles: false)
automaton.save_svg('diagram.svg', 800, 600, pretty: true)
automaton.save_svg('diagram.svg', 800, 600, minify: true)
automaton.save_svg('diagram.svg', 800, 600, state_effect: :shadow)
automaton.save_svg('diagram.svg', 800, 600, loop_position: :right)
automaton.save_svg('diagram.svg', 800, 600, edge_style: :orthogonal)
automaton.save_svg('diagram.svg', 800, 600, state_shape: :ellipse)
automaton.save_svg('diagram.svg', 800, 600, show_final_arrows: true)
```

#### 2. PNG
```ruby
automaton.save_png('diagram.png', 800, 600, theme: :dark)
automaton.save_png('diagram@2x.png', 800, 600, scale: 2.0)
automaton.save_png('diagram.png', 800, 600, converter: :magick)
Graphomaton.png_available?(converter: :auto) #=> true when a PNG converter is installed
```
Generates a PNG file by converting Graphomaton's native SVG output. Requires one of these commands to be available on `PATH`: `rsvg-convert`, `magick`, or `convert`.

#### 3. PDF
```ruby
automaton.save_pdf('diagram.pdf', 800, 600, theme: :print)
automaton.save_pdf('diagram.pdf', 800, 600, converter: :magick)
Graphomaton.pdf_available?(converter: :auto) #=> true when a PDF converter is installed
```
Generates a PDF file by converting Graphomaton's native SVG output. Requires one of these commands to be available on `PATH`: `rsvg-convert`, `magick`, or `convert`.

#### 4. WebP
```ruby
automaton.save_webp('diagram.webp', 800, 600, theme: :dark)
automaton.save_webp('diagram.webp', 800, 600, converter: :magick)
Graphomaton.webp_available?(converter: :auto) #=> true when a WebP converter is installed
```
Generates a WebP file by converting Graphomaton's native SVG output. Requires ImageMagick's `magick` or `convert` command to be available on `PATH`.

#### 5. HTML (Mermaid.js)
```ruby
automaton.save_html('diagram.html')
automaton.save_html('diagram.html', show_source: true)
automaton.save_html('diagram.html', theme: :auto)
automaton.save_html('diagram.html', cdn: './mermaid.min.js', inline_mermaid: true)
automaton.save_html('diagram.html', pan_zoom: true)
automaton.save_html('diagram.html', notes: true)
automaton.save_html('diagram.html', class_defs: true)
```
Generates an HTML file with embedded Mermaid.js state diagram. The diagram is rendered in the browser using Mermaid.js from CDN.

**Note:** Requires internet connection to load Mermaid.js from CDN. Does not work in offline environments.

#### 6. GraphViz (DOT)
```ruby
automaton.save_dot('diagram.dot')
automaton.save_dot('diagram.dot', theme: :ocean)
automaton.save_dot('diagram.dot', rank_constraints: true)
```
Generates a DOT file that can be converted to images using GraphViz:
State and transition metadata keys `url`/`href` and `tooltip`/`description` are emitted as DOT `URL` and `tooltip` attributes.
Transition `line_style: :dashed` and `line_style: :dotted` are emitted as DOT edge `style` attributes.

```bash
dot -Tpng diagram.dot -o diagram.png
dot -Tsvg diagram.dot -o diagram.svg
dot -Tpdf diagram.dot -o diagram.pdf
neato -Tsvg diagram.dot -o diagram-neato.svg
sfdp -Tsvg diagram.dot -o diagram-sfdp.svg
```

Use `dot` for ranked left-to-right or top-to-bottom state-machine layouts. Use `neato` or `sfdp` when you want GraphViz to spread dense or highly connected graphs more freely.

#### 7. PlantUML
```ruby
automaton.save_plantuml('diagram.puml')
automaton.save_plantuml('diagram.puml', theme: :forest)
automaton.save_plantuml('diagram.puml', notes: true)
```
Generates a PlantUML file that can be converted to images using PlantUML server or JAR:
```bash
# Using PlantUML JAR
java -jar plantuml.jar diagram.puml

# Using online server
curl -X POST --data-binary @diagram.puml https://www.plantuml.com/plantuml/png > diagram.png
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/ydah/graphomaton.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Graphomaton project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/ydah/graphomaton/blob/main/CODE_OF_CONDUCT.md).
