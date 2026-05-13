# frozen_string_literal: true

class Graphomaton
  module Exporters
    class Dot
      DEFAULT_DIRECTION = :lr
      DEFAULT_RANK_CONSTRAINTS = false
      DIRECTION_OPTIONS = %i[lr tb rl bt].freeze
      LINE_STYLE_OPTIONS = %i[solid dashed dotted].freeze

      def initialize(automaton, direction: DEFAULT_DIRECTION, theme: nil, rank_constraints: DEFAULT_RANK_CONSTRAINTS)
        @automaton = automaton
        @direction = resolve_direction(direction)
        @theme = resolve_theme(theme)
        @rank_constraints = rank_constraints
      end

      def export
        lines = ['digraph finite_state_machine {']
        lines << "    rankdir=#{rankdir};"
        lines << "    graph [bgcolor=\"#{escape_label(@theme[:background])}\"];" if @theme && @theme[:background]
        lines << "    node [#{node_attributes('circle')}];"
        lines << ''
        state_attributes = state_attribute_lines
        lines.concat(state_attributes)
        lines << '' if state_attributes.any?

        if @automaton.initial_state
          lines << '    __start__ [shape=point];'
          lines << "    __start__ -> \"#{escape_label(@automaton.initial_state)}\";"
          lines << ''
        end

        unless @automaton.final_states.empty?
          final_states_str = @automaton.final_states.map { |s| "\"#{escape_label(s)}\"" }.join(' ')
          lines << "    node [#{node_attributes('doublecircle')}]; #{final_states_str};"
          lines << "    node [#{node_attributes('circle')}];"
          lines << ''
        end

        rank_constraints = rank_constraint_lines
        lines.concat(rank_constraints)
        lines << '' if rank_constraints.any?

        @automaton.transitions.each do |trans|
          from = escape_label(trans[:from])
          to = escape_label(trans[:to])
          lines << "    \"#{from}\" -> \"#{to}\" [#{edge_attributes(trans)}];"
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

      def resolve_theme(theme)
        return nil unless theme

        Graphomaton::Theme.resolve(theme, context: 'DOT theme')
      end

      def node_attributes(shape)
        return "shape = #{shape}" unless @theme

        [
          "shape = #{shape}",
          'style=filled',
          "fillcolor=\"#{escape_label(@theme[:state_fill])}\"",
          "color=\"#{escape_label(@theme[:stroke])}\"",
          "fontcolor=\"#{escape_label(@theme[:state_text])}\""
        ].join(', ')
      end

      def edge_attributes(transition)
        attributes = ["label=\"#{escape_label(transition[:label])}\""]
        add_metadata_attributes(attributes, transition[:metadata])
        add_line_style_attributes(attributes, transition[:line_style])
        if @theme
          attributes << "color=\"#{escape_label(@theme[:stroke])}\""
          attributes << "fontcolor=\"#{escape_label(@theme[:transition_label])}\""
        end
        attributes.join(', ')
      end

      def state_attribute_lines
        @state_attribute_lines ||= @automaton.states.filter_map do |name, state|
          attributes = state_attributes(name, state)
          next if attributes.empty?

          "    \"#{escape_label(name)}\" [#{attributes.join(', ')}];"
        end
      end

      def state_attributes(name, state)
        attributes = []
        label = state[:label]
        attributes << "label=\"#{escape_label(label)}\"" unless label.nil? || label.to_s == name.to_s
        add_metadata_attributes(attributes, state[:metadata])
        attributes
      end

      def add_metadata_attributes(attributes, metadata)
        return unless metadata.is_a?(Hash)

        url = metadata_value(metadata, :url, :href)
        tooltip = metadata_value(metadata, :tooltip, :description)

        attributes << "URL=\"#{escape_label(url)}\"" if url
        attributes << "tooltip=\"#{escape_label(tooltip)}\"" if tooltip
      end

      def add_line_style_attributes(attributes, line_style)
        return unless line_style

        resolved = line_style.to_sym
        unless LINE_STYLE_OPTIONS.include?(resolved)
          raise ArgumentError, "Unknown DOT transition line_style: #{line_style.inspect}. Available values: #{LINE_STYLE_OPTIONS.join(', ')}"
        end

        attributes << "style=\"#{resolved}\"" unless resolved == :solid
      end

      def metadata_value(metadata, *keys)
        keys.each do |key|
          value = metadata[key] || metadata[key.to_s]
          return value if value
        end

        nil
      end

      def rank_constraint_lines
        return [] unless @rank_constraints

        lines = []
        if @automaton.initial_state
          lines << "    { rank=source; \"#{escape_label(@automaton.initial_state)}\"; }"
        end

        unless @automaton.final_states.empty?
          final_states = @automaton.final_states.map { |state| "\"#{escape_label(state)}\";" }.join(' ')
          lines << "    { rank=sink; #{final_states} }"
        end

        lines
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
        label.to_s
             .gsub('\\') { '\\\\' }
             .gsub('"') { '\\"' }
             .gsub("\n") { '\\n' }
      end
    end
  end
end
