# Graphomaton [![Gem Version](https://badge.fury.io/rb/graphomaton.svg?icon=si%3Arubygems)](https://badge.fury.io/rb/graphomaton) [![CI](https://github.com/ydah/graphomaton/actions/workflows/ci.yml/badge.svg)](https://github.com/ydah/graphomaton/actions/workflows/ci.yml)

A tiny Ruby library for generating finite state machine (automaton) diagrams in multiple formats: SVG, HTML (Mermaid.js), GraphViz (DOT), and PlantUML.

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

# Set initial and final states
automaton.set_initial('q0')
automaton.add_final('q2')

# Add transitions
automaton.add_transition('q0', 'q1', 'a')
automaton.add_transition('q1', 'q2', 'b')
automaton.add_transition('q0', 'q0', 'b')
automaton.add_transition('q1', 'q0', 'a')
automaton.add_transition('q2', 'q0', 'b')
automaton.add_transition('q2', 'q1', 'a')

# Save in different formats
automaton.save_svg('output.svg')              # SVG format
automaton.save_html('output.html')            # HTML with Mermaid.js (requires internet)
automaton.save_dot('output.dot')              # GraphViz DOT format
automaton.save_plantuml('output.puml')        # PlantUML format
```

### Output Formats

Graphomaton supports multiple output formats:

#### 1. SVG (Native)
```ruby
automaton.save_svg('diagram.svg', width = 800, height = 600)
```
Generates a standalone SVG file with custom rendering.

#### 2. HTML (Mermaid.js)
```ruby
automaton.save_html('diagram.html')
```
Generates an HTML file with embedded Mermaid.js state diagram. The diagram is rendered in the browser using Mermaid.js from CDN.

**Note:** Requires internet connection to load Mermaid.js from CDN. Does not work in offline environments.

#### 3. GraphViz (DOT)
```ruby
automaton.save_dot('diagram.dot')
```
Generates a DOT file that can be converted to images using GraphViz:
```bash
dot -Tpng diagram.dot -o diagram.png
dot -Tsvg diagram.dot -o diagram.svg
dot -Tpdf diagram.dot -o diagram.pdf
```

#### 4. PlantUML
```ruby
automaton.save_plantuml('diagram.puml')
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
