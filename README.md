# Graphomaton [![Gem Version](https://badge.fury.io/rb/graphomaton.svg?icon=si%3Arubygems)](https://badge.fury.io/rb/graphomaton) [![CI](https://github.com/ydah/graphomaton/actions/workflows/ci.yml/badge.svg)](https://github.com/ydah/graphomaton/actions/workflows/ci.yml)

A tiny Ruby library for generating finite state machine (automaton) diagrams in multiple formats: SVG, PNG, HTML (Mermaid.js), GraphViz (DOT), and PlantUML.

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
automaton.add_transition('q1', 'q1', 'loop', style: { stroke: '#ef4444' }, metadata: { tooltip: 'Highlighted loop' })
automaton.add_transition('q0', 'q0', 'b')
automaton.add_transition('q1', 'q0', 'a')
automaton.add_transition('q2', 'q0', 'b')
automaton.add_transition('q2', 'q1', 'a')

# Save in different formats
automaton.save_svg('output.svg')              # SVG format
automaton.save_png('output.png')              # PNG format (requires a converter)
automaton.save_html('output.html')            # HTML with Mermaid.js (requires internet)
automaton.save_dot('output.dot')              # GraphViz DOT format
automaton.save_plantuml('output.puml')        # PlantUML format

# Or use the unified API
automaton.render(format: :svg, width: 800, height: 600)
automaton.save('output.svg', format: :svg, width: 800, height: 600)

# Validate references before rendering if desired
automaton.validate!
automaton.layout_warnings(800, 600)
```

`label` is used as the display name in SVG, DOT, Mermaid, and PlantUML while the state ID remains stable for transitions.
State metadata `tooltip`/`description` is used as SVG tooltip text. State metadata `url`/`href` creates a clickable SVG state link.

### Themes

Native SVG and PNG output can be rendered with a named theme:

```ruby
automaton.save_svg('output_dark.svg', theme: :dark)
automaton.save_png('output_forest.png', theme: :forest)
automaton.save_svg('output_auto.svg', theme: :auto) # follows prefers-color-scheme
```

Available themes: `:light`, `:dark`, `:forest`, `:ocean`, `:high_contrast`, `:color_blind`, `:print`, `:auto`.

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
`auto_size` expands SVG viewport automatically to the rendered positions when set to `true`.
`arrow_size` controls SVG arrowhead size.
`force` accepts optional tuning keys `padding`, `node_spacing`, `rank_spacing`, `force_iterations`, and `layout_seed`.

You can also control label display behavior:

```ruby
automaton.save_svg('diagram.svg', 800, 600, wrap: true, max_transition_label_width: 120)
automaton.save_svg('diagram.svg', 800, 600, label_background: false)
automaton.save_svg('diagram.svg', 800, 600, label_padding: 16, label_border: true)
automaton.save_svg('diagram.svg', 800, 600, highlight_unreachable: true)
automaton.save_svg('diagram.svg', 800, 600, highlight_dead_states: true)
automaton.save_svg('diagram.svg', 800, 600, highlight_initial_state: true, highlight_final_states: true)
automaton.save_svg('diagram.svg', 800, 600, highlight_transitions: [{ from: 'q0', to: 'q1', label: 'a' }])
automaton.save_svg('diagram.svg', 800, 600, xml_declaration: true)
automaton.save_svg('diagram.svg', 800, 600, css_variables: true)
automaton.save_svg('diagram.svg', 800, 600, pretty: true)
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

#### 3. HTML (Mermaid.js)
```ruby
automaton.save_html('diagram.html')
automaton.save_html('diagram.html', show_source: true)
automaton.save_html('diagram.html', notes: true)
```
Generates an HTML file with embedded Mermaid.js state diagram. The diagram is rendered in the browser using Mermaid.js from CDN.

**Note:** Requires internet connection to load Mermaid.js from CDN. Does not work in offline environments.

#### 4. GraphViz (DOT)
```ruby
automaton.save_dot('diagram.dot')
automaton.save_dot('diagram.dot', theme: :ocean)
```
Generates a DOT file that can be converted to images using GraphViz:
State and transition metadata keys `url`/`href` and `tooltip`/`description` are emitted as DOT `URL` and `tooltip` attributes.

```bash
dot -Tpng diagram.dot -o diagram.png
dot -Tsvg diagram.dot -o diagram.svg
dot -Tpdf diagram.dot -o diagram.pdf
```

#### 5. PlantUML
```ruby
automaton.save_plantuml('diagram.puml')
automaton.save_plantuml('diagram.puml', theme: :forest)
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
