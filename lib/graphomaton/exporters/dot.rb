# frozen_string_literal: true

class Graphomaton
  module Exporters
    class Dot
      include Graphomaton::ExporterIntrospection
      DEFAULT_DIRECTION = :lr
      DEFAULT_RANK_CONSTRAINTS = false
      DIRECTION_OPTIONS = %i[lr tb rl bt].freeze
      LINE_STYLE_OPTIONS = %i[solid dashed dotted].freeze
      PSEUDOSTATE_SHAPES = {
        choice: 'diamond',
        fork: 'point',
        join: 'point'
      }.freeze

      def initialize(automaton, direction: DEFAULT_DIRECTION, theme: nil, rank_constraints: DEFAULT_RANK_CONSTRAINTS)
        @automaton = automaton
        @direction = resolve_direction(direction)
        @theme = resolve_theme(theme)
        @rank_constraints = rank_constraints
        @identifiers = IdentifierAllocator.new
        @state_names = @automaton.state_records.each_key.to_h do |name|
          [name, @identifiers.allocate([:state, name], preferred: name, prefix: 'state')]
        end
        @start_name = @identifiers.allocate(:start, preferred: '__start__', prefix: '__graphomaton_start')
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
        state_clusters = state_cluster_lines
        lines.concat(state_clusters)
        lines << '' if state_clusters.any?

        if @automaton.initial_state
          lines << "    #{quoted_id(@start_name)} [shape=point];"
          lines << "    #{quoted_id(@start_name)} -> #{quoted_state_id(@automaton.initial_state)};"
          lines << ''
        end

        rank_constraints = rank_constraint_lines
        lines.concat(rank_constraints)
        lines << '' if rank_constraints.any?

        @automaton.transition_records.each do |trans|
          lines << "    #{quoted_state_id(trans[:from])} -> #{quoted_state_id(trans[:to])} [#{edge_attributes(trans)}];"
        end

        lines << '}'
        "#{lines.join("\n")}\n"
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
        add_bundle_attribute(attributes, transition[:metadata])
        add_line_style_attributes(attributes, transition[:line_style])
        if @theme
          attributes << "color=\"#{escape_label(@theme[:stroke])}\""
          attributes << "fontcolor=\"#{escape_label(@theme[:transition_label])}\""
        end
        attributes.join(', ')
      end

      def state_attribute_lines
        @state_attribute_lines ||= @automaton.state_records.map do |name, state|
          attributes = state_attributes(name, state)
          suffix = attributes.empty? ? '' : " [#{attributes.join(', ')}]"
          "    #{quoted_state_id(name)}#{suffix};"
        end
      end

      def state_attributes(name, state)
        attributes = []
        label = state[:label]
        identifier = state_name(name)
        pseudostate_shape = @automaton.final_states.include?(name) ? 'doublecircle' : pseudostate_shape(state)
        attributes << "shape=\"#{pseudostate_shape}\"" if pseudostate_shape
        attributes << "label=\"#{escape_label(label || name)}\"" unless label.nil? && identifier == name.to_s
        add_metadata_attributes(attributes, state[:metadata])
        attributes
      end

      def pseudostate_shape(state)
        type = pseudostate_type(state)
        return nil unless type

        PSEUDOSTATE_SHAPES.fetch(type)
      end

      def pseudostate_type(state)
        type = dot_metadata_value(state, :shape) ||
               dot_metadata_value(state, :type) ||
               dot_metadata_value(state, :kind) ||
               state_metadata_value(state, :kind) ||
               state_metadata_value(state, :dot_shape) ||
               state_metadata_value(state, :dot_type) ||
               state_metadata_value(state, :plantuml_shape) ||
               state_metadata_value(state, :plantuml_type) ||
               state_metadata_value(state, :mermaid_shape) ||
               state_metadata_value(state, :mermaid_type)
        normalized = type.to_s.tr('-', '_').to_sym

        PSEUDOSTATE_SHAPES.key?(normalized) ? normalized : nil
      end

      def dot_metadata_value(state, key)
        metadata = state[:metadata]
        return nil unless metadata.is_a?(Hash)

        dot = metadata[:dot] || metadata['dot']
        return nil unless dot.is_a?(Hash)

        dot[key] || dot[key.to_s]
      end

      def state_metadata_value(state, key)
        metadata = state[:metadata]
        return nil unless metadata.is_a?(Hash)

        metadata[key] || metadata[key.to_s]
      end

      def state_cluster_lines
        clusters = @automaton.state_records.each_with_object({}) do |(name, state), groups|
          group = state_group_name(state)
          next unless group

          groups[group] ||= []
          groups[group] << name
        end
        return [] if clusters.empty?

        clusters.flat_map do |group, states|
          [
            "    subgraph #{quoted_id(cluster_name(group))} {",
            "        label=\"#{escape_label(group)}\";",
            *states.map { |state| "        #{quoted_state_id(state)};" },
            '    }'
          ]
        end
      end

      def state_group_name(state)
        metadata = state[:metadata]
        return nil unless metadata.is_a?(Hash)

        metadata_value(metadata, :group, :cluster)
      end

      def add_metadata_attributes(attributes, metadata)
        return unless metadata.is_a?(Hash)

        url = metadata_value(metadata, :url, :href)
        tooltip = metadata_value(metadata, :tooltip, :description)

        if url
          safe_url = UrlPolicy.validate(url, context: 'DOT metadata URL')
          attributes << "URL=\"#{escape_label(safe_url)}\""
        end
        attributes << "tooltip=\"#{escape_label(tooltip)}\"" if tooltip
      end

      def add_bundle_attribute(attributes, metadata)
        return unless metadata.is_a?(Hash)

        bundle = metadata_value(metadata, :bundle)
        return unless bundle

        attributes << "class=\"#{dot_class_name("bundle-#{bundle}")}\""
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
          lines << "    { rank=source; #{quoted_state_id(@automaton.initial_state)}; }"
        end

        unless @automaton.final_states.empty?
          final_states = @automaton.final_states.map { |state| "#{quoted_state_id(state)};" }.join(' ')
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

      def state_name(name)
        @state_names.fetch(name) do
          @identifiers.allocate([:external_state, name], preferred: name, prefix: 'state')
        end
      end

      def quoted_state_id(name)
        quoted_id(state_name(name))
      end

      def quoted_id(identifier)
        "\"#{escape_label(identifier)}\""
      end

      def cluster_name(group)
        identifier = @identifiers.allocate([:group, group], preferred: group, prefix: 'group')
        "cluster_#{identifier}"
      end

      def dot_class_name(value)
        value.to_s.gsub(/[^A-Za-z0-9_-]+/, '-').gsub(/\A-+|-+\z/, '')
      end
    end
  end
end
