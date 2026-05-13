# frozen_string_literal: true

class Graphomaton
  module Exporters
    class Plantuml
      DEFAULT_DIRECTION = :lr
      DEFAULT_NOTES = false
      DIRECTION_OPTIONS = %i[lr tb rl bt].freeze

      def initialize(automaton, direction: DEFAULT_DIRECTION, theme: nil, notes: DEFAULT_NOTES)
        @automaton = automaton
        @direction = resolve_direction(direction)
        @theme = resolve_theme(theme)
        @notes = notes
      end

      def export
        lines = ['@startuml']
        lines << 'hide empty description'

        lines << direction_keyword
        lines.concat(theme_lines) if @theme
        lines.concat(state_alias_lines)
        lines << ''

        if @automaton.initial_state
          lines << "[*] --> #{sanitize_state_name(@automaton.initial_state)}"
        end

        @automaton.transitions.each do |trans|
          from = sanitize_state_name(trans[:from])
          to = sanitize_state_name(trans[:to])
          label = escape_label(trans[:label])
          lines << "#{from} --> #{to} : #{label}"
        end

        @automaton.final_states.each do |state|
          lines << "#{sanitize_state_name(state)} --> [*]"
        end

        lines.concat(state_note_lines) if @notes

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

      def resolve_theme(theme)
        return nil unless theme
        return normalize_theme(theme) if theme.is_a?(Hash)

        Graphomaton::Exporters::Svg::THEMES.fetch(theme.to_s.to_sym)
      rescue KeyError
        available_themes = Graphomaton::Exporters::Svg::THEMES.keys.join(', ')
        raise ArgumentError, "Unknown PlantUML theme: #{theme.inspect}. Available themes: #{available_themes}"
      end

      def normalize_theme(theme)
        normalized = theme.transform_keys { |key| key.to_sym }
        unknown = normalized.keys - Graphomaton::Exporters::Svg::THEMES.fetch(Graphomaton::Exporters::Svg::DEFAULT_THEME).keys
        return Graphomaton::Exporters::Svg::THEMES.fetch(Graphomaton::Exporters::Svg::DEFAULT_THEME).merge(normalized) if unknown.empty?

        raise ArgumentError, "Unknown PlantUML theme keys: #{unknown.join(', ')}"
      end

      def theme_lines
        lines = []
        lines << "skinparam backgroundColor #{@theme[:background]}" if @theme[:background]
        lines << 'skinparam state {'
        lines << "  BackgroundColor #{@theme[:state_fill]}"
        lines << "  BorderColor #{@theme[:stroke]}"
        lines << "  FontColor #{@theme[:state_text]}"
        lines << '}'
        lines << "skinparam ArrowColor #{@theme[:stroke]}"
        lines << "skinparam ArrowFontColor #{@theme[:transition_label]}"
        lines
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

      def escape_label(label)
        label.to_s
             .gsub('\\') { '\\\\' }
             .gsub("\n") { '\\n' }
      end

      def state_alias_lines
        @automaton.states.filter_map do |name, state|
          label = state[:label]
          next if label.nil? || label.to_s == name.to_s

          "state \"#{escape_state_label(label)}\" as #{sanitize_state_name(name)}"
        end
      end

      def state_note_lines
        @automaton.states.filter_map do |name, state|
          note = state_note(state)
          next unless note

          "note right of #{sanitize_state_name(name)} : #{escape_label(note)}"
        end
      end

      def state_note(state)
        metadata = state[:metadata]
        return nil unless metadata.is_a?(Hash)

        metadata[:note] || metadata['note'] ||
          metadata[:description] || metadata['description'] ||
          metadata[:tooltip] || metadata['tooltip']
      end

      def escape_state_label(label)
        label.to_s
             .gsub('\\') { '\\\\' }
             .gsub('"') { '\\"' }
             .gsub("\n") { '\\n' }
      end
    end
  end
end
