# frozen_string_literal: true

class Graphomaton
  module Exporters
    class Dot
      DEFAULT_DIRECTION = :lr
      DIRECTION_OPTIONS = %i[lr tb rl bt].freeze

      def initialize(automaton, direction: DEFAULT_DIRECTION)
        @automaton = automaton
        @direction = resolve_direction(direction)
      end

      def export
        lines = ['digraph finite_state_machine {']
        lines << "    rankdir=#{rankdir};"
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

      def resolve_direction(direction)
        resolved = direction.to_sym
        return resolved if DIRECTION_OPTIONS.include?(resolved)

        raise ArgumentError, "Unknown direction: #{direction.inspect}. Available directions: #{DIRECTION_OPTIONS.join(', ')}"
      end

      def rankdir
        case @direction
        when :tb
          'TB'
        when :bt
          'BT'
        when :rl
          'RL'
        else
          'LR'
        end
      end

      def escape_label(label)
        label.to_s.gsub('"', '\\"')
      end
    end
  end
end
