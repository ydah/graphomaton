# frozen_string_literal: true

class Graphomaton
  class CLI
    class Config
      DEFAULT_PATH = '.graphomaton.yml'
      MAX_BYTES = 1024 * 1024
      FORMAT_SECTIONS = %i[svg png pdf webp html mermaid dot plantuml].freeze
      ENUM_KEYS = %i[
        format input_format theme layout direction fit converter initial_position final_position
        state_shape edge_style arrow_shape state_effect unreachable_zone loop_position diagnostics
      ].freeze
      OPTION_KEYS = %i[
        input input_format output format validate no_clobber width height scale converter timeout
        max_output_bytes max_input_bytes max_states max_transitions max_metadata_depth max_label_length
        max_group_depth theme theme_file layout_warnings
        layout direction fit padding node_spacing rank_spacing force_iterations layout_seed
        graphviz_command auto_density_spacing initial_position final_position responsive state_radius
        auto_state_radius min_state_radius max_state_radius state_stroke_width transition_stroke_width
        state_shape edge_style arrow_shape arrow_size state_effect font_family state_font_weight
        transition_font_weight preserve_manual_positions auto_size xml_declaration pretty minify
        css_variables embed_styles svg_id wrap max_transition_label_width state_wrap
        max_state_label_width label_tooltips html_tooltips sort_labels rotate_labels label_padding
        label_radius label_border label_background initial_arrow_length initial_arrow_label
        final_arrow_length final_arrow_label show_final_arrows scc_groups fold_groups
        highlight_unreachable unreachable_zone highlight_dead_states highlight_initial_state
        highlight_final_states loop_position merge_parallel_transitions title description cdn offline
        inline_mermaid lang show_source pan_zoom mathjax mathjax_cdn notes class_defs rank_constraints
        inline_mathjax self_contained nonce csp mermaid_sha256 mathjax_sha256
        fail_on_warning diagnostics strict_semantics
      ].freeze
      LABEL_KEYS = {
        wrap: :wrap,
        max_width: :max_transition_label_width,
        max_transition_width: :max_transition_label_width,
        state_wrap: :state_wrap,
        max_state_width: :max_state_label_width,
        tooltips: :label_tooltips,
        html_tooltips: :html_tooltips,
        rotate: :rotate_labels,
        padding: :label_padding,
        radius: :label_radius,
        border: :label_border,
        background: :label_background
      }.freeze

      def self.load(path, format: nil, required: false)
        return {} if path.nil?
        return {} unless File.exist?(path) || required

        payload = File.open(path, 'rb') { |input| input.read(MAX_BYTES + 1) }
        raise ArgumentError, "Config exceeds #{MAX_BYTES} bytes" if payload.bytesize > MAX_BYTES

        parsed = YAML.safe_load(payload, permitted_classes: [Symbol], aliases: false) || {}
        raise ArgumentError, 'Config root must be a mapping' unless parsed.is_a?(Hash)

        normalized = symbolize_hash(parsed)
        unknown_sections = normalized.keys - OPTION_KEYS - [:render] - FORMAT_SECTIONS
        raise ArgumentError, "Unknown config keys: #{unknown_sections.join(', ')}" unless unknown_sections.empty?

        common = normalized.reject { |key, _value| key == :render || FORMAT_SECTIONS.include?(key) }
        render = mapping(normalized[:render], 'render')
        format_options = format ? mapping(normalized[format.to_sym], format) : {}
        normalize_options(common.merge(render).merge(format_options))
      rescue Psych::Exception, SystemCallError => e
        raise ArgumentError, "Config error: #{e.message}"
      end

      def self.mapping(value, name)
        return {} if value.nil?
        raise ArgumentError, "Config #{name} section must be a mapping" unless value.is_a?(Hash)

        value
      end
      private_class_method :mapping

      def self.normalize_options(input)
        labels = mapping(input.delete(:labels), 'labels')
        unknown_labels = labels.keys - LABEL_KEYS.keys
        raise ArgumentError, "Unknown config label keys: #{unknown_labels.join(', ')}" unless unknown_labels.empty?

        options = input.merge(labels.to_h { |key, value| [LABEL_KEYS.fetch(key), value] })
        unknown = options.keys - OPTION_KEYS
        raise ArgumentError, "Unknown config option keys: #{unknown.join(', ')}" unless unknown.empty?

        options.to_h do |key, value|
          normalized = ENUM_KEYS.include?(key) && value.is_a?(String) ? value.to_sym : value
          [key, normalized]
        end
      end
      private_class_method :normalize_options

      def self.symbolize_hash(value)
        value.to_h do |key, item|
          normalized = item.is_a?(Hash) ? symbolize_hash(item) : item
          [key.to_s.to_sym, normalized]
        end
      end
      private_class_method :symbolize_hash
    end
  end
end
