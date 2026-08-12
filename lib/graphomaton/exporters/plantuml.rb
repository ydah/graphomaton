# frozen_string_literal: true

class Graphomaton
  module Exporters
    class Plantuml
      DEFAULT_DIRECTION = :lr
      DEFAULT_NOTES = false
      DIRECTION_OPTIONS = %i[lr tb rl bt].freeze
      PSEUDOSTATE_TYPES = %i[choice fork join].freeze
      RESERVED_IDENTIFIERS = %w[state note skinparam hide left right top bottom direction as of].freeze

      def initialize(automaton, direction: DEFAULT_DIRECTION, theme: nil, notes: DEFAULT_NOTES)
        @automaton = automaton
        @direction = resolve_direction(direction)
        @theme = resolve_theme(theme)
        @notes = notes
        @identifiers = IdentifierAllocator.new(reserved: RESERVED_IDENTIFIERS)
        @state_names = allocate_state_names
      end

      def export
        lines = ['@startuml']
        lines << 'hide empty description'

        lines << direction_keyword
        lines.concat(theme_lines) if @theme
        lines.concat(state_alias_lines)
        lines.concat(pseudostate_lines)
        lines.concat(composite_state_lines)
        lines.concat(state_group_lines)
        lines << ''

        if @automaton.initial_state
          lines << "[*] --> #{state_name(@automaton.initial_state)}"
        end

        @automaton.transitions.each do |trans|
          from = state_name(trans[:from])
          to = state_name(trans[:to])
          label = escape_label(trans[:label])
          lines << "#{from} --> #{to} : #{label}"
        end

        @automaton.final_states.each do |state|
          lines << "#{state_name(state)} --> [*]"
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

        Graphomaton::Theme.resolve(theme, context: 'PlantUML theme')
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

      def allocate_state_names
        @automaton.states.each_key.to_h do |name|
          preferred = name.to_s if valid_identifier?(name)
          [name, @identifiers.allocate([:state, name], preferred: preferred, prefix: 'state')]
        end
      end

      def valid_identifier?(name)
        name.to_s.match?(/\A[A-Za-z_][A-Za-z0-9_]*\z/) && !RESERVED_IDENTIFIERS.include?(name.to_s)
      end

      def state_name(name)
        @state_names.fetch(name) do
          @identifiers.allocate([:external_state, name], prefix: 'state')
        end
      end

      def escape_label(label)
        label.to_s
             .gsub('\\') { '\\\\' }
             .gsub("\n") { '\\n' }
      end

      def state_alias_lines
        @automaton.states.filter_map do |name, state|
          next if valid_state_parent(state)
          next if state_group_name(state)
          next if pseudostate_type(state)

          state_declaration_line(name, state)
        end
      end

      def pseudostate_lines
        @automaton.states.filter_map do |name, state|
          type = pseudostate_type(state)
          next unless type
          next if valid_state_parent(state) || state_group_name(state)

          "state #{state_name(name)} <<#{type}>>"
        end
      end

      def pseudostate_type(state)
        type = plantuml_metadata_value(state, :shape) ||
               plantuml_metadata_value(state, :type) ||
               plantuml_metadata_value(state, :kind) ||
               state_metadata_value(state, :plantuml_shape) ||
               state_metadata_value(state, :plantuml_type) ||
               state_metadata_value(state, :mermaid_shape) ||
               state_metadata_value(state, :mermaid_type)
        normalized = type.to_s.tr('-', '_').to_sym

        PSEUDOSTATE_TYPES.include?(normalized) ? normalized : nil
      end

      def plantuml_metadata_value(state, key)
        metadata = state[:metadata]
        return nil unless metadata.is_a?(Hash)

        plantuml = metadata[:plantuml] || metadata['plantuml']
        return nil unless plantuml.is_a?(Hash)

        plantuml[key] || plantuml[key.to_s]
      end

      def state_metadata_value(state, key)
        metadata = state[:metadata]
        return nil unless metadata.is_a?(Hash)

        metadata[key] || metadata[key.to_s]
      end

      def state_group_lines
        groups = @automaton.states.each_with_object({}) do |(name, state), grouped_states|
          group = state_group_name(state)
          next unless group
          next if valid_state_parent(state)

          grouped_states[group] ||= []
          grouped_states[group] << [name, state]
        end
        return [] if groups.empty?

        groups.flat_map do |group, states|
          group_name = @identifiers.allocate([:group, group], prefix: 'group')
          lines = ["state \"#{escape_state_label(group)}\" as #{group_name} {"]
          states.each do |name, state|
            lines << "  #{state_declaration_line(name, state)}"
          end
          lines << '}'
        end
      end

      def state_declaration_line(name, state)
        label = state[:label]
        state_identifier = state_name(name)
        type = pseudostate_type(state)
        stereotype = type ? " <<#{type}>>" : ''

        "state \"#{escape_state_label(label || name)}\" as #{state_identifier}#{stereotype}"
      end

      def composite_state_lines
        children_by_parent = @automaton.states.each_with_object({}) do |(name, state), groups|
          parent = valid_state_parent(state)
          next unless parent

          groups[parent] ||= []
          groups[parent] << [name, state]
        end

        children_by_parent.flat_map do |parent, children|
          parent_state = @automaton.states.fetch(parent)
          label = parent_state[:label] || parent
          lines = ["state \"#{escape_state_label(label)}\" as #{state_name(parent)} {"]
          children.each { |name, state| lines << "  #{state_declaration_line(name, state)}" }
          lines << '}'
        end
      end

      def state_parent(state)
        metadata = state[:metadata]
        return nil unless metadata.is_a?(Hash)

        metadata[:parent] || metadata['parent']
      end

      def valid_state_parent(state)
        parent = state_parent(state)
        return nil unless parent && @automaton.states.key?(parent)

        parent
      end

      def state_group_name(state)
        metadata = state[:metadata]
        return nil unless metadata.is_a?(Hash)

        metadata[:group] || metadata['group'] || metadata[:cluster] || metadata['cluster']
      end

      def state_note_lines
        @automaton.states.filter_map do |name, state|
          note = state_note(state)
          next unless note

          "note right of #{state_name(name)} : #{escape_label(note)}"
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
