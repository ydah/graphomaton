# frozen_string_literal: true

require_relative '../lib/graphomaton'


complex = Graphomaton.new

complex.add_state('A')
complex.add_state('B')
complex.add_state('C')

complex.set_initial('A')
complex.add_final('C')

complex.add_transition('A', 'B', 'x')
complex.add_transition('A', 'B', 'y')

complex.add_transition('B', 'C', 'a')
complex.add_transition('C', 'B', 'b')

complex.add_transition('B', 'B', 'loop')

complex.save_svg('complex_transitions.svg')
puts 'Generated complex_transitions.svg'
