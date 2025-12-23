# frozen_string_literal: true

class Graphomaton
  module Exporters
    class Dot
      def initialize(automaton)
        @automaton = automaton
      end

      def export
        lines = ['digraph finite_state_machine {']
        lines << '    rankdir=LR;'
        lines << '    node [shape = circle];'
        lines << ''

        if @automaton.initial_state
          lines << '    __start__ [shape=point];'
          lines << "    __start__ -> \"#{escape_label(@automaton.initial_state)}\";"
          lines << ''
        end

        unless @automaton.final_states.empty?
          final_states_str = @automaton.final_states.map { |s| "\"#{escape_label(s)}\"" }.join(' ')
          lines << "    node [shape = doublecircle]; #{final_states_str};"
          lines << '    node [shape = circle];'
          lines << ''
        end

        @automaton.transitions.each do |trans|
          from = escape_label(trans[:from])
          to = escape_label(trans[:to])
          label = escape_label(trans[:label])
          lines << "    \"#{from}\" -> \"#{to}\" [label=\"#{label}\"];"
        end

        lines << '}'
        lines.join("\n")
      end

      private

      def escape_label(label)
        label.to_s.gsub('"', '\\"')
      end
    end
  end
end
