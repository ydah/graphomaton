# frozen_string_literal: true

require_relative '../lib/graphomaton'

automaton = Graphomaton.new

automaton.add_state('q0')
automaton.add_state('q1')

automaton.set_initial('q0')
automaton.add_final('q0')

automaton.add_transition('q0', 'q0', '0')
automaton.add_transition('q0', 'q1', '1')
automaton.add_transition('q1', 'q1', '0')
automaton.add_transition('q1', 'q0', '1')

automaton.save_svg('automaton.svg')
puts 'Generated automaton.svg'
