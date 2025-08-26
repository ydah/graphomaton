# Graphomaton [![Gem Version](https://badge.fury.io/rb/graphomaton.svg?icon=si%3Arubygems)](https://badge.fury.io/rb/graphomaton) [![CI](https://github.com/ydah/graphomaton/actions/workflows/ci.yml/badge.svg)](https://github.com/ydah/graphomaton/actions/workflows/ci.yml)

A tiny Ruby library for generating finite state machine (automaton) diagrams as SVG.

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

# Save as SVG
automaton.save_svg('output.svg')
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/ydah/graphomaton.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Graphomaton project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/ydah/graphomaton/blob/main/CODE_OF_CONDUCT.md).
