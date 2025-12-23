# frozen_string_literal: true

require_relative '../lib/graphomaton'

automaton = Graphomaton.new

automaton.add_state('A')
automaton.add_state('B')
automaton.add_state('C')
automaton.add_state('D')

automaton.set_initial('A')
automaton.add_final('D')

automaton.add_transition('A', 'B', '1 step')
automaton.add_transition('A', 'C', 'skip 1 state')
automaton.add_transition('A', 'D', 'skip 2 states')
automaton.add_transition('B', 'C', '1 step')
automaton.add_transition('C', 'D', '1 step')
automaton.add_transition('D', 'A', 'back to start')

automaton.save_svg('skip_states.svg')
puts 'Generated skip_states.svg'
