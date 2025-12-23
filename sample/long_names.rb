# frozen_string_literal: true

require_relative '../lib/graphomaton'

automaton = Graphomaton.new

automaton.add_state('A')
automaton.add_state('Short')
automaton.add_state('Medium Name')
automaton.add_state('VeryLongStateName')

automaton.set_initial('A')
automaton.add_final('VeryLongStateName')

automaton.add_transition('A', 'Short', 'go')
automaton.add_transition('Short', 'Medium Name', 'next')
automaton.add_transition('Medium Name', 'VeryLongStateName', 'final')

automaton.save_svg('long_names.svg')
puts 'Generated long_names.svg'
