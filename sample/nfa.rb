# frozen_string_literal: true

require_relative '../lib/graphomaton'

nfa = Graphomaton.new

nfa.add_state('q0')
nfa.add_state('q1')
nfa.add_state('q2')

nfa.set_initial('q0')
nfa.add_final('q2')

nfa.add_transition('q0', 'q0', 'a,b')
nfa.add_transition('q0', 'q1', 'a')
nfa.add_transition('q1', 'q2', 'b')

nfa.save_svg('nfa_example.svg', 600, 400)
puts 'Generated nfa_example.svg'
