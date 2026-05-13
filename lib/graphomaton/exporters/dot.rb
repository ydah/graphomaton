# frozen_string_literal: true

class Graphomaton
  module Exporters
    class Dot
      DEFAULT_DIRECTION = :lr
      DIRECTION_OPTIONS = %i[lr tb rl bt].freeze

      def initialize(automaton, direction: DEFAULT_DIRECTION, theme: nil)
        @automaton = automaton
        @direction = resolve_direction(direction)
        @theme = resolve_theme(theme)
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
        return normalize_theme(theme) if theme.is_a?(Hash)

        Graphomaton::Exporters::Svg::THEMES.fetch(theme.to_s.to_sym)
      rescue KeyError
        available_themes = Graphomaton::Exporters::Svg::THEMES.keys.join(', ')
        raise ArgumentError, "Unknown DOT theme: #{theme.inspect}. Available themes: #{available_themes}"
      end

      def normalize_theme(theme)
        normalized = theme.transform_keys { |key| key.to_sym }
        unknown = normalized.keys - Graphomaton::Exporters::Svg::THEMES.fetch(Graphomaton::Exporters::Svg::DEFAULT_THEME).keys
        return Graphomaton::Exporters::Svg::THEMES.fetch(Graphomaton::Exporters::Svg::DEFAULT_THEME).merge(normalized) if unknown.empty?

        raise ArgumentError, "Unknown DOT theme keys: #{unknown.join(', ')}"
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

      def metadata_value(metadata, *keys)
        keys.each do |key|
          value = metadata[key] || metadata[key.to_s]
          return value if value
        end

        nil
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
