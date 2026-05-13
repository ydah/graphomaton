# frozen_string_literal: true

class Graphomaton
  module Exporters
    class Plantuml
      DEFAULT_DIRECTION = :lr
      DIRECTION_OPTIONS = %i[lr tb rl bt].freeze

      def initialize(automaton, direction: DEFAULT_DIRECTION)
        @automaton = automaton
        @direction = resolve_direction(direction)
      end

      def export
        lines = ['@startuml']
        lines << 'hide empty description'

        lines << direction_keyword
        lines << ''

        if @automaton.initial_state
          lines << "[*] --> #{sanitize_state_name(@automaton.initial_state)}"
        end

        @automaton.transitions.each do |trans|
          from = sanitize_state_name(trans[:from])
          to = sanitize_state_name(trans[:to])
          label = trans[:label]
          lines << "#{from} --> #{to} : #{label}"
        end

        @automaton.final_states.each do |state|
          lines << "#{sanitize_state_name(state)} --> [*]"
        end

        lines << ''
        lines << '@enduml'
        lines.join("\n")
      end

      private

      def resolve_direction(direction)
        resolved = direction.to_sym
        return resolved if DIRECTION_OPTIONS.include?(resolved)

        raise ArgumentError, "Unknown direction: #{direction.inspect}. Available directions: #{DIRECTION_OPTIONS.join(', ')}"
      end

      def direction_keyword
        case @direction
        when :tb
          'top to bottom direction'
        when :bt
          'bottom to top direction'
        when :rl
          'right to left direction'
        else
          'left to right direction'
        end
      end

      def sanitize_state_name(name)
        sanitized = name.to_s.gsub(/[\s-]/, '_')
        if sanitized =~ /[^\x00-\x7F]/
          "\"#{sanitized}\""
        else
          sanitized
        end
      end
    end
  end
end
