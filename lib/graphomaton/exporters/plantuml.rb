# frozen_string_literal: true

class Graphomaton
  module Exporters
    class Plantuml
      def initialize(automaton)
        @automaton = automaton
      end

      def export
        lines = ['@startuml']
        lines << 'hide empty description'
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
