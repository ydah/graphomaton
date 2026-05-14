# frozen_string_literal: true

require 'rexml/document'
require 'rexml/formatters/pretty'

class Graphomaton
  module Exporters
    class Svg
      DEFAULT_STATE_RADIUS = 40
      DEFAULT_AUTO_STATE_RADIUS = false
      DEFAULT_MIN_STATE_RADIUS = 24
      DEFAULT_MAX_STATE_RADIUS = 72
      DEFAULT_STATE_SHAPE = :circle
      DEFAULT_STATE_STROKE_WIDTH = 2
      DEFAULT_TRANSITION_STROKE_WIDTH = 1.5
      DEFAULT_THEME = :light
      DEFAULT_LAYOUT = :linear
      DEFAULT_DIRECTION = :lr
      DEFAULT_MERGE_PARALLEL_TRANSITIONS = true
      DEFAULT_WRAP = false
      DEFAULT_SORT_LABELS = false
      DEFAULT_ROTATE_LABELS = false
      DEFAULT_LABEL_TOOLTIPS = false
      DEFAULT_HTML_TOOLTIPS = false
      DEFAULT_LABEL_BACKGROUND = true
      DEFAULT_LABEL_BORDER = false
      DEFAULT_LABEL_PADDING = 10
      DEFAULT_LABEL_RADIUS = 3
      DEFAULT_FONT_FAMILY = 'Arial, sans-serif'
      DEFAULT_STATE_FONT_WEIGHT = nil
      DEFAULT_TRANSITION_FONT_WEIGHT = nil
      DEFAULT_HIGHLIGHT_UNREACHABLE = false
      DEFAULT_HIGHLIGHT_DEAD_STATES = false
      DEFAULT_HIGHLIGHT_INITIAL_STATE = false
      DEFAULT_HIGHLIGHT_FINAL_STATES = false
      DEFAULT_HIGHLIGHT_TRANSITIONS = [].freeze
      DEFAULT_UNREACHABLE_ZONE = :none
      DEFAULT_XML_DECLARATION = false
      DEFAULT_CSS_VARIABLES = false
      DEFAULT_EMBED_STYLES = true
      DEFAULT_PRETTY = false
      DEFAULT_MINIFY = false
      DEFAULT_STATE_EFFECT = :none
      DEFAULT_LOOP_POSITION = :auto
      DEFAULT_EDGE_STYLE = :auto
      DEFAULT_SHOW_FINAL_ARROWS = false
      DEFAULT_PADDING = 80
      DEFAULT_NODE_SPACING = 120
      DEFAULT_RANK_SPACING = 120
      DEFAULT_AUTO_DENSITY_SPACING = false
      DEFAULT_FORCE_ITERATIONS = 120
      DEFAULT_ARROW_SIZE = 10
      DEFAULT_ARROW_SHAPE = :triangle
      DEFAULT_INITIAL_ARROW_LENGTH = 30
      DEFAULT_INITIAL_ARROW_LABEL = 'start'
      DEFAULT_FINAL_ARROW_LENGTH = 32
      DEFAULT_FINAL_ARROW_LABEL = 'final'
      DEFAULT_INITIAL_POSITION = :auto
      DEFAULT_FINAL_POSITION = :auto
      DEFAULT_AUTO_SIZE = false
      DEFAULT_MAX_LABEL_WIDTH = 120
      DEFAULT_STATE_WRAP = false
      DEFAULT_MAX_STATE_LABEL_WIDTH = 120
      DEFAULT_SCC_GROUPS = false
      LAYOUT_OPTIONS = %i[linear circle grid layered bfs force manual].freeze
      DIRECTION_OPTIONS = %i[lr tb rl bt].freeze
      LOOP_POSITION_OPTIONS = %i[auto top right bottom left].freeze
      EDGE_STYLE_OPTIONS = %i[auto straight curved orthogonal spline].freeze
      UNREACHABLE_ZONE_OPTIONS = %i[none right bottom].freeze
      STATE_SHAPE_OPTIONS = %i[circle ellipse rounded_rect diamond bar].freeze
      STATE_EFFECT_OPTIONS = %i[none shadow glow pulse].freeze
      ARROW_SHAPE_OPTIONS = %i[triangle vee stealth].freeze
      TRANSITION_LINE_STYLE_OPTIONS = %i[solid dashed dotted].freeze
      TEXT_UNIT_WIDTH = 14.0
      COMBINING_MARK_RANGES = [
        0x0300..0x036F,
        0x1AB0..0x1AFF,
        0x1DC0..0x1DFF,
        0x20D0..0x20FF,
        0xFE20..0xFE2F
      ].freeze
      EAST_ASIAN_WIDE_RANGES = [
        0x1100..0x115F,
        0x2E80..0xA4CF,
        0xAC00..0xD7A3,
        0xF900..0xFAFF,
        0xFE10..0xFE6F,
        0xFF01..0xFF60,
        0xFFE0..0xFFE6,
        0x1F300..0x1FAFF
      ].freeze

      THEMES = {
        light: {
          background: nil,
          state_fill: 'white',
          stroke: '#333',
          state_text: '#333',
          transition_label: '#666',
          label_background: 'white',
          label_opacity: '0.9'
        },
        dark: {
          background: '#111827',
          state_fill: '#1f2937',
          stroke: '#e5e7eb',
          state_text: '#f9fafb',
          transition_label: '#d1d5db',
          label_background: '#111827',
          label_opacity: '0.95'
        },
        forest: {
          background: '#f0fdf4',
          state_fill: '#ecfdf5',
          stroke: '#166534',
          state_text: '#14532d',
          transition_label: '#15803d',
          label_background: '#f0fdf4',
          label_opacity: '0.95'
        },
        ocean: {
          background: '#eff6ff',
          state_fill: '#f8fafc',
          stroke: '#0369a1',
          state_text: '#0c4a6e',
          transition_label: '#0284c7',
          label_background: '#eff6ff',
          label_opacity: '0.95'
        },
        high_contrast: {
          background: '#000000',
          state_fill: '#ffffff',
          stroke: '#ffffff',
          state_text: '#000000',
          transition_label: '#ffff00',
          label_background: '#000000',
          label_opacity: '0.95'
        },
        color_blind: {
          background: '#f7f7f7',
          state_fill: '#ffffff',
          stroke: '#0072b2',
          state_text: '#000000',
          transition_label: '#d55e00',
          label_background: '#f7f7f7',
          label_opacity: '0.95'
        },
        print: {
          background: '#ffffff',
          state_fill: '#ffffff',
          stroke: '#000000',
          state_text: '#000000',
          transition_label: '#000000',
          label_background: '#ffffff',
          label_opacity: '1'
        },
        minimal: {
          background: nil,
          state_fill: '#ffffff',
          stroke: '#111827',
          state_text: '#111827',
          transition_label: '#374151',
          label_background: '#ffffff',
          label_opacity: '0.85'
        },
        academic: {
          background: '#ffffff',
          state_fill: '#f8fafc',
          stroke: '#1e3a8a',
          state_text: '#111827',
          transition_label: '#1e40af',
          label_background: '#ffffff',
          label_opacity: '0.95'
        },
        presentation: {
          background: '#0f172a',
          state_fill: '#f8fafc',
          stroke: '#38bdf8',
          state_text: '#0f172a',
          transition_label: '#facc15',
          label_background: '#0f172a',
          label_opacity: '0.9'
        }
      }.freeze

      def initialize(automaton)
        @automaton = automaton
        @state_radius = DEFAULT_STATE_RADIUS
        @label_padding = DEFAULT_LABEL_PADDING
      end

      def export(width = 800, height = 600, theme: DEFAULT_THEME, layout: DEFAULT_LAYOUT, direction: DEFAULT_DIRECTION, responsive: false,
                 state_radius: DEFAULT_STATE_RADIUS, auto_state_radius: DEFAULT_AUTO_STATE_RADIUS,
                 min_state_radius: DEFAULT_MIN_STATE_RADIUS, max_state_radius: DEFAULT_MAX_STATE_RADIUS,
                 state_shape: DEFAULT_STATE_SHAPE,
                 state_stroke_width: DEFAULT_STATE_STROKE_WIDTH,
                 transition_stroke_width: DEFAULT_TRANSITION_STROKE_WIDTH,
                 wrap: DEFAULT_WRAP, max_transition_label_width: DEFAULT_MAX_LABEL_WIDTH,
                 state_wrap: DEFAULT_STATE_WRAP, max_state_label_width: DEFAULT_MAX_STATE_LABEL_WIDTH,
                 sort_labels: DEFAULT_SORT_LABELS,
                 label_tooltips: DEFAULT_LABEL_TOOLTIPS,
                 html_tooltips: DEFAULT_HTML_TOOLTIPS,
                 font_family: DEFAULT_FONT_FAMILY,
                 state_font_weight: DEFAULT_STATE_FONT_WEIGHT,
                 transition_font_weight: DEFAULT_TRANSITION_FONT_WEIGHT,
                 padding: DEFAULT_PADDING, node_spacing: DEFAULT_NODE_SPACING, rank_spacing: DEFAULT_RANK_SPACING,
                 force_iterations: DEFAULT_FORCE_ITERATIONS, layout_seed: nil, auto_size: DEFAULT_AUTO_SIZE,
                 auto_density_spacing: DEFAULT_AUTO_DENSITY_SPACING,
                 arrow_size: DEFAULT_ARROW_SIZE,
                 arrow_shape: DEFAULT_ARROW_SHAPE,
                 initial_arrow_length: DEFAULT_INITIAL_ARROW_LENGTH,
                 initial_arrow_label: DEFAULT_INITIAL_ARROW_LABEL,
                 final_arrow_length: DEFAULT_FINAL_ARROW_LENGTH,
                 final_arrow_label: DEFAULT_FINAL_ARROW_LABEL,
                 initial_position: DEFAULT_INITIAL_POSITION, final_position: DEFAULT_FINAL_POSITION,
                 merge_parallel_transitions: DEFAULT_MERGE_PARALLEL_TRANSITIONS,
                 label_background: DEFAULT_LABEL_BACKGROUND,
                 label_border: DEFAULT_LABEL_BORDER,
                 label_padding: DEFAULT_LABEL_PADDING,
                 label_radius: DEFAULT_LABEL_RADIUS,
                 rotate_labels: DEFAULT_ROTATE_LABELS,
                 highlight_unreachable: DEFAULT_HIGHLIGHT_UNREACHABLE,
                 highlight_dead_states: DEFAULT_HIGHLIGHT_DEAD_STATES,
                 highlight_initial_state: DEFAULT_HIGHLIGHT_INITIAL_STATE,
                 highlight_final_states: DEFAULT_HIGHLIGHT_FINAL_STATES,
                 highlight_transitions: DEFAULT_HIGHLIGHT_TRANSITIONS,
                 unreachable_zone: DEFAULT_UNREACHABLE_ZONE,
                 xml_declaration: DEFAULT_XML_DECLARATION,
                 css_variables: DEFAULT_CSS_VARIABLES,
                 embed_styles: DEFAULT_EMBED_STYLES,
                 pretty: DEFAULT_PRETTY,
                 minify: DEFAULT_MINIFY,
                 state_effect: DEFAULT_STATE_EFFECT,
                 loop_position: DEFAULT_LOOP_POSITION,
                 edge_style: DEFAULT_EDGE_STYLE,
                 show_final_arrows: DEFAULT_SHOW_FINAL_ARROWS,
                 scc_groups: DEFAULT_SCC_GROUPS,
                 preserve_manual_positions: Graphomaton::DEFAULT_PRESERVE_MANUAL_POSITIONS,
                 fit: Graphomaton::DEFAULT_FIT,
                 title: nil, description: nil, svg_id: nil)
        @state_radius = resolve_state_radius(state_radius, auto_state_radius, min_state_radius, max_state_radius)
        @state_shape = resolve_state_shape(state_shape)
        @state_stroke_width = [state_stroke_width.to_f, 0.1].max
        @transition_stroke_width = [transition_stroke_width.to_f, 0.1].max
        @arrow_size = [arrow_size.to_f, 1.0].max
        @arrow_shape = resolve_arrow_shape(arrow_shape)
        @initial_arrow_length = [initial_arrow_length.to_f, 1.0].max
        @initial_arrow_label = initial_arrow_label
        @final_arrow_length = [final_arrow_length.to_f, 1.0].max
        @final_arrow_label = final_arrow_label
        @auto_dark_theme = false
        @theme = resolve_theme(theme)
        @layout = resolve_layout(layout)
        @direction = resolve_direction(direction)
        @loop_position = resolve_loop_position(loop_position)
        @edge_style = resolve_edge_style(edge_style)
        @state_effect = resolve_state_effect(state_effect)
        @show_final_arrows = show_final_arrows
        @merge_parallel_transitions = merge_parallel_transitions
        @label_background = label_background
        @label_border = label_border
        @label_padding = [label_padding.to_f, 0].max
        @label_radius = [label_radius.to_f, 0].max
        @rotate_labels = rotate_labels
        @highlight_unreachable = highlight_unreachable
        @highlight_dead_states = highlight_dead_states
        @highlight_initial_state = highlight_initial_state
        @highlight_final_states = highlight_final_states
        @highlight_transitions = Array(highlight_transitions)
        @unreachable_zone = resolve_unreachable_zone(unreachable_zone)
        @css_variables = css_variables || @auto_dark_theme
        @unreachable_states = (@highlight_unreachable || @unreachable_zone != :none) ? @automaton.unreachable_states : []
        @dead_states = @highlight_dead_states ? @automaton.dead_states : []
        @trap_states = @highlight_dead_states ? @automaton.trap_states : []
        @padding = padding
        @node_spacing, @rank_spacing = density_adjusted_spacings(node_spacing, rank_spacing, auto_density_spacing)
        @force_iterations = force_iterations
        @layout_seed = layout_seed
        @wrap_labels = wrap
        @state_wrap = state_wrap
        @max_state_label_width = max_state_label_width
        @scc_groups = scc_groups
        @max_transition_label_width = max_transition_label_width
        @sort_labels = sort_labels
        @label_tooltips = label_tooltips
        @html_tooltips = html_tooltips
        @font_family = font_family
        @state_font_weight = state_font_weight
        @transition_font_weight = transition_font_weight
        @positions = @automaton.layout_positions(
          width,
          height,
          layout: @layout,
          direction: @direction,
          state_radius: @state_radius,
          padding: @padding,
          node_spacing: @node_spacing,
          rank_spacing: @rank_spacing,
          force_iterations: @force_iterations,
          layout_seed: @layout_seed,
          initial_position: initial_position,
          final_position: final_position,
          preserve_manual_positions: preserve_manual_positions,
          fit: fit
        )
        @positions = apply_unreachable_zone(@positions, width, height)
        if auto_size
          width, height = auto_size_canvas(width, height)
        end
        @label_boxes = []
        @title_text = title
        @description_text = description
        @svg_id = svg_id ? svg_id_component(svg_id) : "graphomaton-#{object_id}"
        @arrowhead_id = "#{@svg_id}-arrowhead"
        @element_id_counts = Hash.new(0)

        doc = REXML::Document.new
        svg = doc.add_element('svg', svg_root_attributes(width, height, responsive: responsive))

        add_defs(svg)
        add_style(svg) if embed_styles
        add_accessibility_metadata(svg)
        add_embedded_metadata(svg)
        add_background(svg, width, height)
        transition_group = svg.add_element('g', { 'class' => 'transitions' })
        state_group = svg.add_element('g', { 'class' => 'states' })
        add_transitions(transition_group)
        add_initial_arrow(transition_group) if @automaton.initial_state
        add_final_arrows(transition_group) if @show_final_arrows
        add_state_groups(state_group)
        add_states(state_group)

        svg_output = serialize_document(doc, pretty: pretty, minify: minify)
        return svg_output unless xml_declaration

        %(<?xml version="1.0" encoding="UTF-8"?>\n#{svg_output})
      end

      private

      def serialize_document(doc, pretty:, minify:)
        raise ArgumentError, 'SVG pretty and minify options cannot both be true' if pretty && minify

        return minify_document(doc) if minify
        return doc.to_s unless pretty

        output = +''
        formatter = REXML::Formatters::Pretty.new(2)
        formatter.compact = true
        formatter.write(doc, output)
        output
      end

      def minify_document(doc)
        doc.elements.each('//style') do |style|
          style.text = style.text.to_s.gsub(/\s+/, ' ').strip
        end

        doc.to_s.gsub(/>\s+</, '><')
      end

      def resolve_theme(theme)
        unless theme.is_a?(Hash)
          theme_name = theme.to_s.to_sym
          if theme_name == :auto
            @auto_dark_theme = true
            return Graphomaton::Theme.resolve(theme, context: 'SVG theme', allow_auto: true)
          end
        end

        Graphomaton::Theme.resolve(theme, context: 'SVG theme', allow_auto: true)
      end

      def resolve_layout(layout)
        resolved = layout.to_sym
        return resolved if LAYOUT_OPTIONS.include?(resolved)

        raise ArgumentError, "Unknown SVG layout: #{layout.inspect}. Available layouts: #{LAYOUT_OPTIONS.join(', ')}"
      end

      def resolve_direction(direction)
        resolved = direction.to_sym
        return resolved if DIRECTION_OPTIONS.include?(resolved)

        raise ArgumentError, "Unknown direction: #{direction.inspect}. Available directions: #{DIRECTION_OPTIONS.join(', ')}"
      end

      def resolve_loop_position(loop_position)
        resolved = loop_position.to_sym
        return resolved if LOOP_POSITION_OPTIONS.include?(resolved)

        raise ArgumentError, "Unknown loop_position: #{loop_position.inspect}. Available values: #{LOOP_POSITION_OPTIONS.join(', ')}"
      end

      def resolve_edge_style(edge_style)
        resolved = edge_style.to_sym
        return resolved if EDGE_STYLE_OPTIONS.include?(resolved)

        raise ArgumentError, "Unknown edge_style: #{edge_style.inspect}. Available values: #{EDGE_STYLE_OPTIONS.join(', ')}"
      end

      def resolve_state_shape(state_shape)
        resolved = state_shape.to_sym
        return resolved if STATE_SHAPE_OPTIONS.include?(resolved)

        raise ArgumentError, "Unknown state_shape: #{state_shape.inspect}. Available values: #{STATE_SHAPE_OPTIONS.join(', ')}"
      end

      def resolve_state_effect(state_effect)
        resolved = state_effect.to_sym
        return resolved if STATE_EFFECT_OPTIONS.include?(resolved)

        raise ArgumentError, "Unknown state_effect: #{state_effect.inspect}. Available values: #{STATE_EFFECT_OPTIONS.join(', ')}"
      end

      def resolve_unreachable_zone(unreachable_zone)
        resolved = unreachable_zone.to_sym
        return resolved if UNREACHABLE_ZONE_OPTIONS.include?(resolved)

        raise ArgumentError, "Unknown unreachable_zone: #{unreachable_zone.inspect}. Available values: #{UNREACHABLE_ZONE_OPTIONS.join(', ')}"
      end

      def resolve_arrow_shape(arrow_shape)
        resolved = arrow_shape.to_sym
        return resolved if ARROW_SHAPE_OPTIONS.include?(resolved)

        raise ArgumentError, "Unknown arrow_shape: #{arrow_shape.inspect}. Available values: #{ARROW_SHAPE_OPTIONS.join(', ')}"
      end

      def apply_unreachable_zone(positions, width, height)
        return positions if @unreachable_zone == :none || @unreachable_states.empty?

        moved_positions = positions.transform_values(&:dup)
        states = @unreachable_states.select { |state| moved_positions.key?(state) }
        return positions if states.empty?

        margin = [@padding.to_f, @state_radius + 20].max
        spacing = [@node_spacing.to_f, @state_radius * 2.5].max
        if @unreachable_zone == :bottom
          y = height.to_f - margin
          start_x = centered_zone_start(width.to_f, states.size, spacing, margin)
          states.each_with_index do |state, index|
            moved_positions[state][:x] = start_x + (index * spacing)
            moved_positions[state][:y] = y
          end
        else
          x = width.to_f - margin
          start_y = centered_zone_start(height.to_f, states.size, spacing, margin)
          states.each_with_index do |state, index|
            moved_positions[state][:x] = x
            moved_positions[state][:y] = start_y + (index * spacing)
          end
        end

        moved_positions
      end

      def centered_zone_start(size, count, spacing, margin)
        span = [count - 1, 0].max * spacing
        [[(size - span) / 2.0, margin].max, size - margin - span].min
      end

      def density_adjusted_spacings(node_spacing, rank_spacing, auto_density_spacing)
        resolved_node_spacing = node_spacing.to_f
        resolved_rank_spacing = rank_spacing.to_f
        return [resolved_node_spacing, resolved_rank_spacing] unless auto_density_spacing

        state_count = @automaton.states.size
        return [resolved_node_spacing, resolved_rank_spacing] if state_count <= 4

        multiplier = 1.0 + ([[state_count - 4, 16].min, 0].max * 0.06)
        [
          (resolved_node_spacing * multiplier).round(2),
          (resolved_rank_spacing * multiplier).round(2)
        ]
      end

      def auto_size_canvas(width, height)
        x_values = @positions.values.map { |position| position[:x].to_f }
        y_values = @positions.values.map { |position| position[:y].to_f }
        return [width.to_f, height.to_f] if x_values.empty? || y_values.empty?

        min_x = x_values.min
        max_x = x_values.max
        min_y = y_values.min
        max_y = y_values.max

        return [width.to_f, height.to_f] unless min_x && max_x && min_y && max_y

        horizontal_margin = [@padding.to_f, @state_radius + 20].max
        vertical_margin = [@padding.to_f, @state_radius + 20].max
        shift_x = min_x - horizontal_margin
        shift_y = min_y - vertical_margin

        if shift_x.nonzero? || shift_y.nonzero?
          @positions.each_value do |position|
            position[:x] -= shift_x
            position[:y] -= shift_y
          end
        end

        width = (max_x - min_x) + (horizontal_margin * 2)
        height = (max_y - min_y) + (vertical_margin * 2)
        [width.to_f, height.to_f]
      end

      def svg_root_attributes(width, height, responsive:)
        {
          'xmlns' => 'http://www.w3.org/2000/svg',
          'id' => @svg_id,
          'viewBox' => "0 0 #{width} #{height}",
          'preserveAspectRatio' => 'xMidYMid meet',
          'role' => 'img',
          'aria-labelledby' => "#{@svg_id}-title #{@svg_id}-desc",
          'width' => (responsive ? '100%' : width.to_s),
          'height' => (responsive ? 'auto' : height.to_s)
        }
      end

      def add_accessibility_metadata(svg)
        title = svg.add_element('title', { 'id' => "#{@svg_id}-title" })
        title.text = @title_text || 'Finite state machine diagram'

        description = svg.add_element('desc', { 'id' => "#{@svg_id}-desc" })
        description.text = @description_text || generated_description
      end

      def generated_description
        state_count = @automaton.states.size
        transition_count = @automaton.transitions.size

        "Automaton with #{state_count} states and #{transition_count} transitions."
      end

      def add_embedded_metadata(svg)
        metadata = svg.add_element('metadata')
        metadata.add_element('graphomaton', {
                               'generator' => 'graphomaton',
                               'version' => Graphomaton::VERSION,
                               'format' => 'svg'
                             })
      end

      def resolve_state_radius(state_radius, auto_state_radius, min_state_radius, max_state_radius)
        radius = [state_radius.to_f, 1.0].max
        return radius unless auto_state_radius

        min_radius = [min_state_radius.to_f, 1.0].max
        max_radius = [max_state_radius.to_f, min_radius].max
        label_radius = state_label_radius

        [[radius, label_radius, min_radius].max, max_radius].min
      end

      def state_label_radius
        max_width_units = @automaton.states.map do |name, state|
          text_display_width_units(state_label(name, state))
        end.max || 0
        return DEFAULT_STATE_RADIUS if max_width_units <= 0

        ((max_width_units * 20) / 1.7).ceil
      end

      def calculate_text_width(text)
        width = (text_display_width_units(text) * TEXT_UNIT_WIDTH) + (@label_padding * 2)
        [width.ceil, 60].max
      end

      def calculate_state_font_size(name)
        estimated_width = text_display_width_units(name)
        available_width = (@state_radius || DEFAULT_STATE_RADIUS) * 1.7

        base_size = 20
        calculated_size = if estimated_width * base_size > available_width
                            (available_width / estimated_width).floor
                          else
                            base_size
                          end

        [calculated_size, 12].max
      end

      def text_display_width_units(text)
        text.to_s.each_char.sum { |char| character_width_units(char) }
      end

      def character_width_units(char)
        codepoint = char.ord
        return 0.0 if zero_width_codepoint?(codepoint)
        return 0.4 if char.match?(/\s/)
        return 1.0 if codepoint_in_ranges?(codepoint, EAST_ASIAN_WIDE_RANGES)
        return 0.55 if codepoint < 0x80

        0.65
      end

      def zero_width_codepoint?(codepoint)
        codepoint == 0x200D ||
          codepoint == 0xFE0F ||
          codepoint_in_ranges?(codepoint, COMBINING_MARK_RANGES)
      end

      def codepoint_in_ranges?(codepoint, ranges)
        ranges.any? { |range| range.cover?(codepoint) }
      end

      def add_defs(svg)
        defs = svg.add_element('defs')
        marker_height = @arrow_size * 0.6
        marker = defs.add_element('marker', {
                                    'id' => @arrowhead_id,
                                    'markerWidth' => @arrow_size.to_s,
                                    'markerHeight' => marker_height.to_s,
                                    'refX' => (@arrow_size * 0.9).to_s,
                                    'refY' => (marker_height / 2).to_s,
                                    'orient' => 'auto',
                                    'markerUnits' => 'strokeWidth'
                                  })
        add_arrowhead_shape(marker, marker_height)
      end

      def add_arrowhead_shape(marker, marker_height)
        case @arrow_shape
        when :vee
          marker.add_element('polyline', {
                               'points' => "0 0, #{@arrow_size} #{marker_height / 2}, 0 #{marker_height}",
                               'fill' => 'none',
                               'stroke' => theme_css_value(:stroke),
                               'stroke-width' => '1.5',
                               'stroke-linecap' => 'round',
                               'stroke-linejoin' => 'round'
                             })
        when :stealth
          marker.add_element('polygon', {
                               'points' => "0 0, #{@arrow_size} #{marker_height / 2}, 0 #{marker_height}, #{@arrow_size * 0.35} #{marker_height / 2}",
                               'fill' => theme_css_value(:stroke)
                             })
        else
          marker.add_element('polygon', {
                               'points' => "0 0, #{@arrow_size} #{marker_height / 2}, 0 #{marker_height}",
                               'fill' => theme_css_value(:stroke)
                             })
        end
      end

      def add_style(svg)
        style = svg.add_element('style')
        background = theme_css_value(:background, fallback: 'transparent')
        style.text = <<-CSS
#{css_variables_css}      
      .diagram-background { fill: #{background}; }
      .state-circle { fill: #{theme_css_value(:state_fill)}; stroke: #{theme_css_value(:stroke)}; stroke-width: #{@state_stroke_width}; vector-effect: non-scaling-stroke; shape-rendering: geometricPrecision; #{state_effect_css} }
      .final-state { stroke-width: #{final_state_stroke_width}; }
      .state-text { font-family: #{@font_family}; text-anchor: middle; fill: #{theme_css_value(:state_text)}; text-rendering: geometricPrecision; #{font_weight_css(@state_font_weight)} }
      .state-icon { font-family: #{@font_family}; text-anchor: middle; fill: #{theme_css_value(:state_text)}; font-size: 14px; text-rendering: geometricPrecision; }
      .transition-line { stroke: #{theme_css_value(:stroke)}; stroke-width: #{@transition_stroke_width}; fill: none; marker-end: url(##{@arrowhead_id}); vector-effect: non-scaling-stroke; shape-rendering: geometricPrecision; stroke-linecap: round; stroke-linejoin: round; }
      .transition-label { font-family: #{@font_family}; font-size: 14px; fill: #{theme_css_value(:transition_label)}; text-rendering: geometricPrecision; #{font_weight_css(@transition_font_weight)} }
      .initial-arrow { stroke: #{theme_css_value(:stroke)}; stroke-width: #{arrow_stroke_width}; fill: none; marker-end: url(##{@arrowhead_id}); vector-effect: non-scaling-stroke; shape-rendering: geometricPrecision; stroke-linecap: round; stroke-linejoin: round; }
      .final-arrow { stroke: #{theme_css_value(:stroke)}; stroke-width: #{arrow_stroke_width}; fill: none; marker-end: url(##{@arrowhead_id}); vector-effect: non-scaling-stroke; shape-rendering: geometricPrecision; stroke-linecap: round; stroke-linejoin: round; }
      .label-bg { fill: #{theme_css_value(:label_background)}; opacity: #{theme_css_value(:label_opacity)}; #{label_border_css} }
      .state-group-box { fill: #{theme_css_value(:stroke)}; opacity: 0.08; stroke: #{theme_css_value(:stroke)}; stroke-width: 1; stroke-dasharray: 6 4; }
      .state-group-label { font-family: #{@font_family}; font-size: 12px; fill: #{theme_css_value(:state_text)}; font-weight: 700; text-rendering: geometricPrecision; }
      .unreachable-state { opacity: 0.45; }
      .initial-state .state-circle { fill: #dbeafe; }
      .accepting-state .state-circle { fill: #dcfce7; }
      .dead-state { opacity: 0.65; }
      .dead-state .state-circle { stroke-dasharray: 6 4; }
      .trap-state .state-circle { stroke-dasharray: 2 4; }
      .highlighted-transition .transition-line { stroke: #ef4444; stroke-width: #{highlighted_transition_stroke_width}; }
      .inactive-transition { opacity: 0.25; }
#{state_effect_animation_css}
        CSS
      end

      def label_border_css
        return 'stroke: none;' unless @label_border

        "stroke: #{theme_css_value(:stroke)}; stroke-width: 1; vector-effect: non-scaling-stroke;"
      end

      def font_weight_css(weight)
        return '' if weight.nil?

        "font-weight: #{weight};"
      end

      def css_variables_css
        return '' unless @css_variables

        base_css = css_variable_scope(@svg_id, @theme)
        return base_css unless @auto_dark_theme

        <<-CSS
#{base_css}      @media (prefers-color-scheme: dark) {
#{css_variable_scope(@svg_id, THEMES.fetch(:dark), indentation: '        ')}      }
        CSS
      end

      def css_variable_scope(svg_id, theme, indentation: '      ')
        variable_keys = %i[background state_fill stroke state_text transition_label label_background label_opacity]
        declarations = variable_keys.filter_map do |key|
          value = theme[key] || (key == :background ? 'transparent' : nil)
          next unless value

          "#{indentation}  --graphomaton-#{css_variable_name(key)}: #{value};"
        end.join("\n")

        "#{indentation}##{svg_id} {\n#{declarations}\n#{indentation}}\n"
      end

      def theme_css_value(key, fallback: nil)
        value = @theme[key] || fallback
        return value unless @css_variables

        "var(--graphomaton-#{css_variable_name(key)}, #{value})"
      end

      def css_variable_name(key)
        key.to_s.tr('_', '-')
      end

      def state_effect_css
        case @state_effect
        when :shadow
          'filter: drop-shadow(0 4px 8px rgba(15, 23, 42, 0.25));'
        when :glow
          "filter: drop-shadow(0 0 8px #{theme_css_value(:stroke)});"
        when :pulse
          "filter: drop-shadow(0 0 6px #{theme_css_value(:stroke)}); animation: graphomaton-pulse 1.8s ease-in-out infinite; transform-box: fill-box; transform-origin: center;"
        else
          ''
        end
      end

      def state_effect_animation_css
        return '' unless @state_effect == :pulse

        <<-CSS
      @keyframes graphomaton-pulse {
        0%, 100% { opacity: 1; filter: drop-shadow(0 0 4px #{theme_css_value(:stroke)}); }
        50% { opacity: 0.72; filter: drop-shadow(0 0 14px #{theme_css_value(:stroke)}); }
      }
      @media (prefers-reduced-motion: reduce) {
        .state-circle { animation: none; }
      }
        CSS
      end

      def final_state_stroke_width
        @state_stroke_width * 2
      end

      def arrow_stroke_width
        @transition_stroke_width + 0.5
      end

      def highlighted_transition_stroke_width
        @transition_stroke_width + 1.0
      end

      def add_background(svg, width, height)
        return unless @theme[:background]

        svg.add_element('rect', {
                          'class' => 'diagram-background',
                          'x' => '0',
                          'y' => '0',
                          'width' => width.to_s,
                          'height' => height.to_s
                        })
      end

      def add_transitions(svg)
        processed_pairs = {}
        from_state_indices = {}
        self_loop_indices = Hash.new(0)

        transition_groups.each do |group|
          first = group.first
          from_state = state_position(first[:from])
          to_state = state_position(first[:to])
          next if from_state.nil? || to_state.nil?

          if @merge_parallel_transitions || group.size == 1
            transition = first.dup
            transition[:label] = merged_label(group)

            if from_state == to_state
              loop_index = self_loop_indices[first[:from]]
              self_loop_indices[first[:from]] += 1
              add_self_loop(svg, from_state, transition, loop_index)
            else
              from_state_indices[first[:from]] = 0 unless from_state_indices.key?(first[:from])
              from_state_index = from_state_indices[first[:from]]
              from_state_indices[first[:from]] += 1

              add_transition(svg, from_state, to_state, transition, processed_pairs, from_state_index)
            end
          else
            group.each do |transition|
              add_self_loop(svg, from_state, transition, self_loop_indices[first[:from]])
              self_loop_indices[first[:from]] += 1
            end
          end
        end
      end

      def transition_groups
        return @automaton.transitions.map { |transition| [transition] } unless @merge_parallel_transitions

        grouped = {}
        @automaton.transitions.each do |transition|
          grouped[transition_key(transition)] ||= []
          grouped[transition_key(transition)] << transition
        end
        grouped.values
      end

      def transition_key(transition)
        [transition[:from], transition[:to]]
      end

      def merged_label(group)
        return group.first[:label] if group.size == 1

        labels = group.map { |transition| transition[:label].to_s }
        labels = labels.uniq
        labels = labels.sort if @sort_labels
        labels.join(', ')
      end

      def add_self_loop(svg, state, trans, loop_index = 0)
        transition_node = svg.add_element('g', transition_group_attributes(trans))
        add_transition_tooltip(transition_node, trans)
        transition_content = transition_link_container(transition_node, trans)
        cx = state[:x]
        cy = state[:y]
        orientation, layer = self_loop_placement(loop_index)
        loop_specs = self_loop_specs(
          orientation,
          layer: layer,
          loop_index: loop_index
        )

        loop_height = loop_specs[:loop_height]
        loop_width = loop_specs[:loop_width]
        loop_offset = loop_specs[:loop_offset]
        start_angle = loop_specs[:start_angle] * Math::PI / 180
        end_angle = loop_specs[:end_angle] * Math::PI / 180
        radius = @state_radius

        start_x = cx + (radius * Math.cos(start_angle))
        start_y = cy + (radius * Math.sin(start_angle))
        end_x = cx + (radius * Math.cos(end_angle))
        end_y = cy + (radius * Math.sin(end_angle))

        control1_x = cx + loop_specs[:control1][:x]
        control1_y = cy + loop_specs[:control1][:y]
        control2_x = cx + loop_specs[:control2][:x]
        control2_y = cy + loop_specs[:control2][:y]

        path_d = "M #{start_x} #{start_y} C #{control1_x} #{control1_y}, #{control2_x} #{control2_y}, #{end_x} #{end_y}"

        transition_content.add_element('path', transition_line_attributes(trans, 'd' => path_d))

        text_width = calculate_text_width(trans[:label])
        label_y_shift = loop_offset * (loop_index.odd? ? -1 : 1)
        if @label_background
          transition_content.add_element('rect', {
                                           'class' => 'label-bg',
                                           'x' => (cx + loop_specs[:label_offset][:x] - (text_width / 2)).to_s,
                                           'y' => (cy + loop_specs[:label_offset][:y] - 5 + label_y_shift).to_s,
                                           'width' => text_width.to_s,
                                           'height' => '20',
                                           'rx' => @label_radius.to_s
                                         })
        end

        label = transition_content.add_element('text', {
                                                'class' => 'transition-label',
                                                'x' => (cx + loop_specs[:label_offset][:x]).to_s,
                                                'y' => (cy + loop_specs[:label_offset][:y] + 10 + label_y_shift).to_s,
                                                'text-anchor' => 'middle'
                                              })
        label.text = trans[:label]
      end

      def self_loop_placement(loop_index)
        return [@loop_position, loop_index] unless @loop_position == :auto

        orientations = %i[top right bottom left]
        [orientations[loop_index % orientations.size], loop_index / orientations.size]
      end

      def self_loop_specs(orientation, layer:, loop_index:)
        angle_shift = loop_index.even? ? 0 : 4
        loop_height = (@state_radius * 2.0) + (layer * 20)
        loop_width = @state_radius + 5 + (layer * 10)
        loop_offset = layer * 8

        case orientation
        when :top
          {
            loop_height: loop_height,
            loop_width: loop_width,
            loop_offset: loop_offset,
            start_angle: -145 + angle_shift,
            end_angle: -35 - angle_shift,
            control1: { x: -loop_width - loop_offset, y: -loop_height - loop_offset },
            control2: { x: loop_width + loop_offset, y: -loop_height - loop_offset },
            label_offset: { x: 0.0, y: -(loop_height + 8) }
          }
        when :right
          {
            loop_height: loop_height,
            loop_width: loop_width,
            loop_offset: loop_offset,
            start_angle: -35 + angle_shift,
            end_angle: 55 - angle_shift,
            control1: { x: loop_height + loop_offset, y: -loop_width - loop_offset },
            control2: { x: loop_height + loop_offset, y: loop_width + loop_offset },
            label_offset: { x: loop_height + 10, y: 0.0 }
          }
        when :bottom
          {
            loop_height: loop_height,
            loop_width: loop_width,
            loop_offset: loop_offset,
            start_angle: 35 + angle_shift,
            end_angle: 145 - angle_shift,
            control1: { x: -loop_width - loop_offset, y: loop_height + loop_offset },
            control2: { x: loop_width + loop_offset, y: loop_height + loop_offset },
            label_offset: { x: 0.0, y: loop_height + 8 }
          }
        else
          {
            loop_height: loop_height,
            loop_width: loop_width,
            loop_offset: loop_offset,
            start_angle: 125 + angle_shift,
            end_angle: 235 - angle_shift,
            control1: { x: -(loop_height + loop_offset), y: -loop_width - loop_offset },
            control2: { x: -(loop_height + loop_offset), y: loop_width + loop_offset },
            label_offset: { x: -(loop_height + 10), y: 0.0 }
          }
        end
      end

      def transition_label_lines(label)
        wrapped_lines(label, @wrap_labels ? @max_transition_label_width : 0)
      end

      def state_label_lines(name)
        wrapped_lines(name, @state_wrap ? @max_state_label_width : 0)
      end

      def wrapped_lines(value, max_width)
        text = value.to_s
        return [text] if max_width.nil? || max_width <= 0

        max_width = max_width.to_f
        return [text] if max_width <= 0

        lines = []
        current = +''
        words = text.split(/\s+/)
        words.each do |word|
          if calculate_text_width(word) > max_width
            lines << current unless current.empty?
            split_words = split_long_word(word, max_width)
            split_words.each do |split_word|
              candidate = current.empty? ? split_word : "#{current} #{split_word}"
              if calculate_text_width(candidate) > max_width && !current.empty?
                lines << current
                current = split_word
              else
                current = candidate
              end
            end
            lines << current unless current.empty?
            current = +''
            next
          end

          candidate = current.empty? ? word : "#{current} #{word}"
          if calculate_text_width(candidate) > max_width && !current.empty?
            lines << current
            current = word
          else
            current = candidate
          end
        end

        lines << current unless current.empty?
        lines = [''] if lines.empty?
        lines
      end

      def split_long_word(word, max_width)
        return [word] if word.empty?

        chunks = []
        current = +''
        word.each_char do |char|
          candidate = current.empty? ? char : "#{current}#{char}"
          if calculate_text_width(candidate) > max_width && !current.empty?
            chunks << current
            current = char
          else
            current = candidate
          end
        end

        chunks << current unless current.empty?
        chunks
      end

      def transition_label_box_lines_width(lines)
        lines.map { |line| calculate_text_width(line) }.max || 60
      end

      def transition_label_box_height(lines)
        [16 * [lines.size, 1].max, 20].max
      end

      def collision_free_label_box(base_box)
        box = base_box.dup
        attempts = 0
        max_attempts = 32
        while (label_box_overlap?(box) || label_box_overlaps_state?(box)) && attempts < max_attempts
          offset_x, offset_y = label_box_offset(attempts)
          box = {
            x: base_box[:x] + offset_x,
            y: base_box[:y] + offset_y,
            width: base_box[:width],
            height: base_box[:height]
          }
          attempts += 1
        end
        box
      end

      def label_box_offset(attempt)
        return [0, 0] if attempt.zero?

        step = 8
        directions = [[0, 1], [0, -1], [1, 0], [-1, 0], [1, 1], [1, -1], [-1, 1], [-1, -1]]
        ring = attempt / directions.size
        index = attempt % directions.size
        direction = directions[index]

        multiplier = [1, ring + 1].max
        [direction[0] * step * multiplier, direction[1] * step * multiplier]
      end

      def label_box_overlap?(box)
        @label_boxes.any? do |existing|
          !(box[:x] + box[:width] < existing[:x] ||
            box[:x] > existing[:x] + existing[:width] ||
            box[:y] + box[:height] < existing[:y] ||
            box[:y] > existing[:y] + existing[:height])
        end
      end

      def label_box_overlaps_state?(box)
        @positions.each_value do |state|
          next if state[:x].nil? || state[:y].nil?

          closest_x = if state[:x] < box[:x]
                        box[:x]
                      elsif state[:x] > (box[:x] + box[:width])
                        box[:x] + box[:width]
                      else
                        state[:x]
                      end

          closest_y = if state[:y] < box[:y]
                        box[:y]
                      elsif state[:y] > (box[:y] + box[:height])
                        box[:y] + box[:height]
                      else
                        state[:y]
                      end

          dx = state[:x] - closest_x
          dy = state[:y] - closest_y
        return true if (dx * dx + dy * dy) < (@state_radius * @state_radius)
        end

        false
      end

      def add_transition(svg, from_state, to_state, trans, processed_pairs, from_state_index)
        transition_node = svg.add_element('g', transition_group_attributes(trans))
        add_transition_tooltip(transition_node, trans)
        transition_content = transition_link_container(transition_node, trans)
        x1 = from_state[:x]
        y1 = from_state[:y]
        x2 = to_state[:x]
        y2 = to_state[:y]

        pair_key = [trans[:from].to_s, trans[:to].to_s].sort.join('-')
        processed_pairs[pair_key] = 0 unless processed_pairs[pair_key]

        pair_index = processed_pairs[pair_key]
        processed_pairs[pair_key] += 1

        parallel_count = @automaton.count_parallel_transitions(trans[:from], trans[:to])

        dx = x2 - x1
        dy = y2 - y1
        dist = Math.sqrt((dx**2) + (dy**2))
        if dist <= 0
          add_overlapping_state_transition(transition_content, x1, y1, trans)
          return
        end

        radius = @state_radius
        start_x = x1 + ((dx / dist) * radius)
        start_y = y1 + ((dy / dist) * radius)
        end_x = x2 - ((dx / dist) * radius)
        end_y = y2 - ((dy / dist) * radius)

        state_names = @automaton.states.keys
        from_index = state_names.index(trans[:from])
        to_index = state_names.index(trans[:to])

        is_adjacent = (to_index - from_index).abs == 1
        states_between = (to_index - from_index).abs - 1

        if @edge_style == :straight
          add_straight_line(transition_content, start_x, start_y, end_x, end_y, trans)
        elsif @edge_style == :curved
          add_curved_line(
            transition_content,
            start_x,
            start_y,
            end_x,
            end_y,
            x1,
            y1,
            x2,
            y2,
            trans,
            parallel_count,
            pair_index,
            states_between,
            from_state_index
          )
        elsif @edge_style == :spline
          add_spline_line(transition_content, start_x, start_y, end_x, end_y, x1, y1, x2, y2, trans, pair_index)
        elsif @edge_style == :orthogonal
          add_orthogonal_line(transition_content, start_x, start_y, end_x, end_y, trans)
        elsif is_adjacent && forward_direction?(x1, y1, x2, y2) && !edge_crosses_other_state?(trans, start_x, start_y, end_x, end_y)
          add_straight_line(transition_content, start_x, start_y, end_x, end_y, trans)
        else
          add_curved_line(
            transition_content,
            start_x,
            start_y,
            end_x,
            end_y,
            x1,
            y1,
            x2,
            y2,
            trans,
            parallel_count,
            pair_index,
            states_between,
            from_state_index
          )
        end
      end

      def add_straight_line(svg, start_x, start_y, end_x, end_y, trans)
        svg.add_element(
          'line',
          transition_line_attributes(
            trans,
            'x1' => start_x.to_s,
            'y1' => start_y.to_s,
            'x2' => end_x.to_s,
            'y2' => end_y.to_s
          )
        )

        label_x = (start_x + end_x) / 2
        label_y = ((start_y + end_y) / 2) - 10

        add_label(svg, label_x, label_y, trans[:label], angle: label_rotation_angle(start_x, start_y, end_x, end_y))
      end

      def add_curved_line(svg, start_x, start_y, end_x, end_y, x1, y1, x2, y2, trans, parallel_count, pair_index, states_between, from_state_index)
        mid_x = (start_x + end_x) / 2
        mid_y = (start_y + end_y) / 2

        base_offset = if states_between > 0
                        (@state_radius * 1.5) + (states_between * 30) + (from_state_index * 120)
                      else
                        @state_radius * 2
                      end

        curve_offset = if parallel_count > 1
                         if forward_direction?(x1, y1, x2, y2)
                           -(base_offset + (50 * pair_index))
                         else
                           base_offset + (50 * pair_index)
                         end
                       elsif forward_direction?(x1, y1, x2, y2)
                         -base_offset
                       else
                         base_offset
                       end

        if vertical_direction?
          control_x = mid_x + curve_offset
          control_y = if (y2 - y1).abs < 10
                        mid_y + (50 * (pair_index.even? ? 1 : -1))
                      else
                        mid_y
                      end
        else
          control_x = if (x2 - x1).abs < 10
                        mid_x + (50 * (pair_index.even? ? 1 : -1))
                      else
                        mid_x
                      end
          control_y = mid_y + curve_offset
        end

        path_d = "M #{start_x} #{start_y} Q #{control_x} #{control_y}, #{end_x} #{end_y}"

        svg.add_element('path', transition_line_attributes(trans, 'd' => path_d))

        t = 0.5
        label_x = ((1 - t) * (1 - t) * start_x) + (2 * (1 - t) * t * control_x) + (t * t * end_x)
        label_y = ((1 - t) * (1 - t) * start_y) + (2 * (1 - t) * t * control_y) + (t * t * end_y)

        add_label(svg, label_x, label_y, trans[:label], angle: label_rotation_angle(start_x, start_y, end_x, end_y))
      end

      def add_spline_line(svg, start_x, start_y, end_x, end_y, x1, y1, x2, y2, trans, pair_index)
        dx = end_x - start_x
        dy = end_y - start_y
        distance = Math.sqrt((dx**2) + (dy**2))
        return add_straight_line(svg, start_x, start_y, end_x, end_y, trans) if distance <= 0

        normal_x = -dy / distance
        normal_y = dx / distance
        bend = @state_radius + (pair_index * 24)
        bend *= forward_direction?(x1, y1, x2, y2) ? -1 : 1
        control1_x = start_x + (dx * 0.35) + (normal_x * bend)
        control1_y = start_y + (dy * 0.35) + (normal_y * bend)
        control2_x = start_x + (dx * 0.65) + (normal_x * bend)
        control2_y = start_y + (dy * 0.65) + (normal_y * bend)
        path_d = "M #{start_x} #{start_y} C #{control1_x} #{control1_y}, #{control2_x} #{control2_y}, #{end_x} #{end_y}"

        svg.add_element('path', transition_line_attributes(trans, 'd' => path_d))

        t = 0.5
        label_x = cubic_bezier_point(start_x, control1_x, control2_x, end_x, t)
        label_y = cubic_bezier_point(start_y, control1_y, control2_y, end_y, t)
        add_label(svg, label_x, label_y, trans[:label], angle: label_rotation_angle(control1_x, control1_y, control2_x, control2_y))
      end

      def edge_crosses_other_state?(transition, start_x, start_y, end_x, end_y)
        @positions.any? do |name, position|
          next false if name == transition[:from] || name == transition[:to]
          next false unless position[:x] && position[:y]

          distance_to_segment(
            position[:x].to_f,
            position[:y].to_f,
            start_x,
            start_y,
            end_x,
            end_y
          ) < (@state_radius + 8)
        end
      end

      def distance_to_segment(point_x, point_y, start_x, start_y, end_x, end_y)
        dx = end_x - start_x
        dy = end_y - start_y
        length_squared = (dx**2) + (dy**2)
        return Math.sqrt(((point_x - start_x)**2) + ((point_y - start_y)**2)) if length_squared <= 0

        t = (((point_x - start_x) * dx) + ((point_y - start_y) * dy)) / length_squared
        t = [[t, 0.0].max, 1.0].min
        projection_x = start_x + (t * dx)
        projection_y = start_y + (t * dy)
        Math.sqrt(((point_x - projection_x)**2) + ((point_y - projection_y)**2))
      end

      def cubic_bezier_point(start_value, control1_value, control2_value, end_value, t)
        inverse = 1 - t
        (inverse**3 * start_value) +
          (3 * inverse * inverse * t * control1_value) +
          (3 * inverse * t * t * control2_value) +
          (t**3 * end_value)
      end

      def add_orthogonal_line(svg, start_x, start_y, end_x, end_y, trans)
        if vertical_direction?
          mid_y = (start_y + end_y) / 2.0
          path_d = "M #{start_x} #{start_y} L #{start_x} #{mid_y} L #{end_x} #{mid_y} L #{end_x} #{end_y}"
          label_x = (start_x + end_x) / 2.0
          label_y = mid_y - 8
          label_angle = label_rotation_angle(start_x, mid_y, end_x, mid_y)
        else
          mid_x = (start_x + end_x) / 2.0
          path_d = "M #{start_x} #{start_y} L #{mid_x} #{start_y} L #{mid_x} #{end_y} L #{end_x} #{end_y}"
          label_x = mid_x
          label_y = ((start_y + end_y) / 2.0) - 8
          label_angle = label_rotation_angle(mid_x, start_y, mid_x, end_y)
        end

        svg.add_element('path', transition_line_attributes(trans, 'd' => path_d))
        add_label(svg, label_x, label_y, trans[:label], angle: label_angle)
      end

      def add_overlapping_state_transition(svg, x, y, trans)
        radius = @state_radius
        loop_height = radius * 2.0
        loop_width = radius + 10
        start_x = x + radius
        start_y = y
        end_x = x
        end_y = y - radius
        control1_x = x + loop_width
        control1_y = y - loop_height
        control2_x = x + loop_height
        control2_y = y - loop_width
        path_d = "M #{start_x} #{start_y} C #{control1_x} #{control1_y}, #{control2_x} #{control2_y}, #{end_x} #{end_y}"

        svg.add_element('path', transition_line_attributes(trans, 'd' => path_d))
        add_label(svg, x + loop_width, y - loop_height, trans[:label])
      end

      def add_label(svg, x, y, text, angle: nil)
        lines = transition_label_lines(text)
        text_width = transition_label_box_lines_width(lines)
        text_height = transition_label_box_height(lines)

        base_box = {
          x: x - (text_width / 2),
          y: y - (text_height / 2),
          width: text_width,
          height: text_height
        }
        box = collision_free_label_box(base_box)
        @label_boxes << box
        transform = label_rotation_transform(box, angle)

        if @label_background
          label_background_attributes = {
            'class' => 'label-bg',
            'x' => box[:x].to_s,
            'y' => box[:y].to_s,
            'width' => box[:width].to_s,
            'height' => box[:height].to_s,
            'rx' => @label_radius.to_s
          }
          label_background_attributes['transform'] = transform if transform
          svg.add_element('rect', label_background_attributes)
        end

        label_attributes = {
          'class' => 'transition-label',
          'x' => (box[:x] + (box[:width] / 2)).to_s,
          'y' => (box[:y] + 12).to_s,
          'text-anchor' => 'middle'
        }
        label_attributes['transform'] = transform if transform
        label = svg.add_element('text', label_attributes)
        if lines.size == 1
          label.text = lines.first
        else
          lines.each_with_index do |line, index|
            tspan = label.add_element('tspan', { 'x' => (box[:x] + (box[:width] / 2)).to_s })
            tspan.text = line
            tspan.attributes['dy'] = index.zero? ? '0' : '16'
          end
        end
      end

      def label_rotation_angle(start_x, start_y, end_x, end_y)
        angle = Math.atan2(end_y - start_y, end_x - start_x) * 180.0 / Math::PI
        angle += 180.0 if angle < -90.0
        angle -= 180.0 if angle > 90.0
        angle.round(2)
      end

      def label_rotation_transform(box, angle)
        return nil unless @rotate_labels && angle

        center_x = box[:x] + (box[:width] / 2.0)
        center_y = box[:y] + (box[:height] / 2.0)
        "rotate(#{angle} #{center_x} #{center_y})"
      end

      def add_initial_arrow(svg)
        init = state_position(@automaton.initial_state)
        init ||= @automaton.states[@automaton.initial_state]
        return unless init

        return unless init[:x] && init[:y]

        initial_node = svg.add_element('g', {
                                         'class' => 'initial-transition',
                                         'id' => unique_svg_id("transition-start-#{svg_id_component(@automaton.initial_state)}"),
                                         'data-to' => @automaton.initial_state.to_s
                                       })

        x1, y1, x2, y2, label_x, label_y, anchor = initial_arrow_points(init)
        initial_node.add_element('line', {
                                   'class' => 'initial-arrow',
                                   'x1' => x1.to_s,
                                   'y1' => y1.to_s,
                                   'x2' => x2.to_s,
                                   'y2' => y2.to_s
                                 })

        return if @initial_arrow_label.nil?

        start_label = initial_node.add_element('text', {
                                                'class' => 'transition-label',
                                                'x' => label_x.to_s,
                                                'y' => label_y.to_s,
                                                'text-anchor' => anchor
                                              })
        start_label.text = @initial_arrow_label
      end

      def initial_arrow_points(state)
        x = state[:x].to_f
        y = state[:y].to_f
        gap = 30
        length = @initial_arrow_length

        case @direction
        when :rl
          [x + gap + length, y, x + gap, y, x + gap + length + 10, y - 10, 'start']
        when :tb
          [x, y - gap - length, x, y - gap, x + 8, y - gap - length - 8, 'start']
        when :bt
          [x, y + gap + length, x, y + gap, x + 8, y + gap + length + 16, 'start']
        else
          [x - gap - length, y, x - gap, y, x - gap - length - 10, y - 10, 'end']
        end
      end

      def add_final_arrows(svg)
        @automaton.final_states.each do |state_name|
          state = state_position(state_name) || @automaton.states[state_name]
          next unless state && state[:x] && state[:y]

          x1, y1, x2, y2, label_x, label_y, anchor = final_arrow_points(state)
          final_node = svg.add_element('g', {
                                         'class' => 'final-transition',
                                         'id' => unique_svg_id("transition-#{svg_id_component(state_name)}-final"),
                                         'data-from' => state_name.to_s
                                       })
          final_node.add_element('line', {
                                   'class' => 'final-arrow',
                                   'x1' => x1.to_s,
                                   'y1' => y1.to_s,
                                   'x2' => x2.to_s,
                                   'y2' => y2.to_s
                                 })
          next if @final_arrow_label.nil?

          label = final_node.add_element('text', {
                                          'class' => 'transition-label',
                                          'x' => label_x.to_s,
                                          'y' => label_y.to_s,
                                          'text-anchor' => anchor
                                        })
          label.text = @final_arrow_label
        end
      end

      def final_arrow_points(state)
        x = state[:x].to_f
        y = state[:y].to_f
        radius = @state_radius
        length = @final_arrow_length

        case @direction
        when :rl
          [x - radius, y, x - radius - length, y, x - radius - length - 8, y - 8, 'end']
        when :tb
          [x, y + radius, x, y + radius + length, x + 8, y + radius + length + 16, 'start']
        when :bt
          [x, y - radius, x, y - radius - length, x + 8, y - radius - length - 8, 'start']
        else
          [x + radius, y, x + radius + length, y, x + radius + length + 8, y - 8, 'start']
        end
      end

      def add_state_groups(svg)
        groups = grouped_state_positions
        return if groups.empty?

        groups.each do |name, positions|
          bounds = state_group_bounds(positions)
          svg.add_element('rect', {
                            'class' => 'state-group-box',
                            'x' => bounds[:x].to_s,
                            'y' => bounds[:y].to_s,
                            'width' => bounds[:width].to_s,
                            'height' => bounds[:height].to_s,
                            'rx' => '12'
                          })
          label = svg.add_element('text', {
                                    'class' => 'state-group-label',
                                    'x' => (bounds[:x] + 12).to_s,
                                    'y' => (bounds[:y] + 22).to_s
                                  })
          label.text = name.to_s
        end
      end

      def grouped_state_positions
        groups = @automaton.states.each_with_object({}) do |(name, state), grouped|
          group_name = state_group_name(state)
          next unless group_name

          position = state_position(name)
          next unless position && position[:x] && position[:y]

          grouped[group_name] ||= []
          grouped[group_name] << position
        end
        add_scc_state_groups(groups) if @scc_groups
        groups
      end

      def add_scc_state_groups(groups)
        strongly_connected_components.each_with_index do |component, index|
          next if component.size < 2

          group_name = "SCC #{index + 1}"
          groups[group_name] ||= []
          component.each do |state|
            position = state_position(state)
            groups[group_name] << position if position && position[:x] && position[:y]
          end
          groups.delete(group_name) if groups[group_name].empty?
        end
      end

      def strongly_connected_components
        index = 0
        stack = []
        indexes = {}
        lowlinks = {}
        on_stack = {}
        components = []

        @automaton.states.each_key do |state|
          next if indexes.key?(state)

          strong_connect(state, index, stack, indexes, lowlinks, on_stack, components)
          index = indexes.size
        end

        components
      end

      def strong_connect(state, index, stack, indexes, lowlinks, on_stack, components)
        indexes[state] = index
        lowlinks[state] = index
        stack << state
        on_stack[state] = true

        adjacent_states(state).each do |target|
          next unless @automaton.states.key?(target)

          unless indexes.key?(target)
            strong_connect(target, indexes.size, stack, indexes, lowlinks, on_stack, components)
            lowlinks[state] = [lowlinks[state], lowlinks[target]].min
          end
          lowlinks[state] = [lowlinks[state], indexes[target]].min if on_stack[target]
        end

        return unless lowlinks[state] == indexes[state]

        component = []
        loop do
          member = stack.pop
          on_stack[member] = false
          component << member
          break if member == state
        end
        components << component
      end

      def adjacent_states(state)
        @automaton.transitions.filter_map do |transition|
          transition[:to] if transition[:from] == state
        end
      end

      def state_group_name(state)
        metadata = state[:metadata]
        return nil unless metadata.is_a?(Hash)

        metadata[:group] || metadata['group'] || metadata[:cluster] || metadata['cluster']
      end

      def state_group_bounds(positions)
        padding = [@state_radius * 0.75, 28].max
        min_x = positions.map { |position| position[:x].to_f }.min - @state_radius - padding
        max_x = positions.map { |position| position[:x].to_f }.max + @state_radius + padding
        min_y = positions.map { |position| position[:y].to_f }.min - @state_radius - padding
        max_y = positions.map { |position| position[:y].to_f }.max + @state_radius + padding

        {
          x: min_x,
          y: min_y,
          width: max_x - min_x,
          height: max_y - min_y
        }
      end

      def add_states(svg)
        @automaton.states.each do |name, state|
          label = state_label(name, state)
          lines = state_label_lines(label)
          position = state_position(name) || state
          state_node = svg.add_element('g', state_group_attributes(name))
          add_state_tooltip(state_node, state, label)
          state_content = state_link_container(state_node, state)
          shape = state_shape(state)
          circle_class = 'state-circle'
          circle_class += ' final-state' if @automaton.final_states.include?(name)

          state_content.add_element(state_shape_element(shape), state_shape_attributes(shape, circle_class, position, state))

          if @automaton.final_states.include?(name)
            inner_radius = [@state_radius - 8, 8].max
            state_content.add_element(state_shape_element(shape), state_shape_attributes(shape, 'state-circle', position, state, radius: inner_radius))
          end
          add_state_icon(state_content, state, position)

          font_size = calculate_state_font_size(label.to_s)
          if lines.size == 1
            text = state_content.add_element('text', {
                                               'class' => 'state-text',
                                               'x' => position[:x].to_s,
                                               'y' => (position[:y] + (font_size * 0.35)).to_s,
                                               'font-size' => font_size.to_s
                                             })
            text.text = lines.first
          else
            line_gap = font_size + 2
            text_start_y = position[:y].to_f - ((lines.size - 1) * line_gap / 2.0) + (line_gap * 0.35)
            text = state_content.add_element('text', {
                                               'class' => 'state-text',
                                               'x' => position[:x].to_s,
                                               'y' => text_start_y.to_s,
                                               'font-size' => font_size.to_s
                                             })
            lines.each_with_index do |line, index|
              tspan = text.add_element('tspan', { 'x' => position[:x].to_s })
              tspan.text = line
              tspan.attributes['dy'] = index.zero? ? '0' : line_gap.to_s
            end
          end
        end
      end

      def state_label(name, state)
        state.fetch(:label, name)
      end

      def add_state_icon(state_content, state, position)
        icon = state_icon(state)
        return unless icon

        icon_text = state_content.add_element('text', {
                                               'class' => 'state-icon',
                                               'x' => position[:x].to_s,
                                               'y' => (position[:y].to_f - (@state_radius * 0.35)).to_s
                                             })
        icon_text.text = icon.to_s
      end

      def state_icon(state)
        metadata = state[:metadata]
        return nil unless metadata.is_a?(Hash)

        metadata[:icon] || metadata['icon']
      end

      def state_shape(state)
        return resolve_state_shape(state[:shape]) if state[:shape]

        pseudostate_shape(state) || @state_shape
      end

      def pseudostate_shape(state)
        type = nested_state_metadata_value(state, :svg, :shape) ||
               nested_state_metadata_value(state, :svg, :type) ||
               nested_state_metadata_value(state, :plantuml, :shape) ||
               nested_state_metadata_value(state, :plantuml, :type) ||
               nested_state_metadata_value(state, :mermaid, :shape) ||
               nested_state_metadata_value(state, :mermaid, :type) ||
               state_metadata_value(state, :svg_shape) ||
               state_metadata_value(state, :svg_type) ||
               state_metadata_value(state, :plantuml_shape) ||
               state_metadata_value(state, :plantuml_type) ||
               state_metadata_value(state, :mermaid_shape) ||
               state_metadata_value(state, :mermaid_type)
        normalized = type.to_s.tr('-', '_').to_sym

        case normalized
        when :choice
          :diamond
        when :fork, :join
          :bar
        end
      end

      def state_metadata_value(state, key)
        metadata = state[:metadata]
        return nil unless metadata.is_a?(Hash)

        metadata[key] || metadata[key.to_s]
      end

      def nested_state_metadata_value(state, namespace, key)
        metadata = state[:metadata]
        return nil unless metadata.is_a?(Hash)

        nested = metadata[namespace] || metadata[namespace.to_s]
        return nil unless nested.is_a?(Hash)

        nested[key] || nested[key.to_s]
      end

      def add_state_tooltip(state_node, state, label)
        tooltip = state_tooltip(state, label)
        return unless tooltip

        title = state_node.add_element('title')
        title.text = tooltip
        add_html_tooltip_attributes(state_node, tooltip)
      end

      def state_link_container(state_node, state)
        url = state_url(state)
        return state_node unless url

        state_node.add_element('a', {
                                 'href' => url.to_s,
                                 'target' => '_blank',
                                 'rel' => 'noopener noreferrer'
                               })
      end

      def state_url(state)
        metadata = state[:metadata]
        return nil unless metadata.is_a?(Hash)

        metadata[:url] || metadata['url'] || metadata[:href] || metadata['href']
      end

      def state_tooltip(state, label)
        metadata = state[:metadata]
        if metadata.is_a?(Hash)
          tooltip = metadata[:tooltip] || metadata['tooltip'] || metadata[:description] || metadata['description']
          return tooltip if tooltip
        end

        return nil unless @label_tooltips

        label.to_s
      end

      def state_shape_element(shape)
        return 'polygon' if shape == :diamond
        return 'rect' if shape == :bar
        return 'ellipse' if shape == :ellipse
        return 'rect' if shape == :rounded_rect

        'circle'
      end

      def state_shape_attributes(shape, shape_class, position, state, radius: @state_radius)
        attributes = case shape
                     when :diamond
                       {
                         'class' => shape_class,
                         'points' => [
                           "#{position[:x]} #{position[:y].to_f - radius}",
                           "#{position[:x].to_f + radius} #{position[:y]}",
                           "#{position[:x]} #{position[:y].to_f + radius}",
                           "#{position[:x].to_f - radius} #{position[:y]}"
                         ].join(', ')
                       }
                     when :bar
                       bar_width = radius * 1.4
                       bar_height = [radius * 0.2, 8].max
                       {
                         'class' => shape_class,
                         'x' => (position[:x].to_f - (bar_width / 2.0)).to_s,
                         'y' => (position[:y].to_f - (bar_height / 2.0)).to_s,
                         'width' => bar_width.to_s,
                         'height' => bar_height.to_s,
                         'rx' => (bar_height / 2.0).to_s
                       }
                     when :ellipse
                       {
                         'class' => shape_class,
                         'cx' => position[:x].to_s,
                         'cy' => position[:y].to_s,
                         'rx' => (radius * 1.25).to_s,
                         'ry' => (radius * 0.8).to_s
                       }
                     when :rounded_rect
                       {
                         'class' => shape_class,
                         'x' => (position[:x] - radius).to_s,
                         'y' => (position[:y] - radius).to_s,
                         'width' => (radius * 2).to_s,
                         'height' => (radius * 2).to_s,
                         'rx' => '10'
                       }
                     else
                       {
                         'class' => shape_class,
                         'cx' => position[:x].to_s,
                         'cy' => position[:y].to_s,
                         'r' => radius.to_s
                       }
                     end
        style = css_style(state[:style])
        attributes['style'] = style unless style.empty?
        attributes
      end

      def css_style(style)
        return '' unless style.is_a?(Hash)

        style.map do |key, value|
          "#{key.to_s.tr('_', '-')}: #{value}"
        end.join('; ')
      end

      def state_group_attributes(name)
        classes = ['state']
        classes << 'unreachable-state' if @unreachable_states.include?(name)
        classes << 'dead-state' if @dead_states.include?(name)
        classes << 'trap-state' if @trap_states.include?(name)
        classes << 'initial-state' if @highlight_initial_state && @automaton.initial_state == name
        classes << 'accepting-state' if @highlight_final_states && @automaton.final_states.include?(name)

        {
          'class' => classes.join(' '),
          'id' => unique_svg_id("state-#{svg_id_component(name)}"),
          'data-state' => name.to_s
        }
      end

      def transition_group_attributes(transition)
        from = transition[:from]
        to = transition[:to]
        label = transition[:label]
        bundle = transition_bundle(transition)
        classes = ['transition']
        classes << 'bundled-transition' if bundle
        if highlighted_transition?(transition)
          classes << 'highlighted-transition'
        elsif @highlight_transitions.any?
          classes << 'inactive-transition'
        end

        attributes = {
          'class' => classes.join(' '),
          'id' => unique_svg_id(
            "transition-#{svg_id_component(from)}-#{svg_id_component(to)}-#{svg_id_component(label)}"
          ),
          'data-from' => from.to_s,
          'data-to' => to.to_s,
          'data-label' => label.to_s
        }
        attributes['data-bundle'] = bundle.to_s if bundle
        attributes
      end

      def transition_bundle(transition)
        metadata = transition[:metadata]
        return nil unless metadata.is_a?(Hash)

        metadata[:bundle] || metadata['bundle']
      end

      def transition_line_attributes(transition, attributes)
        line_attributes = { 'class' => 'transition-line' }.merge(attributes)
        style = transition_css_style(transition)
        line_attributes['style'] = style unless style.empty?
        line_attributes
      end

      def transition_css_style(transition)
        style = []
        line_style = transition[:line_style]
        line_style_value = line_style_css(line_style) if line_style
        style << line_style_value unless line_style_value.to_s.empty?
        custom_style = css_style(transition[:style])
        style << custom_style unless custom_style.empty?
        style.join('; ')
      end

      def line_style_css(line_style)
        resolved = line_style.to_sym
        unless TRANSITION_LINE_STYLE_OPTIONS.include?(resolved)
          raise ArgumentError, "Unknown transition line_style: #{line_style.inspect}. Available values: #{TRANSITION_LINE_STYLE_OPTIONS.join(', ')}"
        end

        case resolved
        when :dashed
          'stroke-dasharray: 8 5'
        when :dotted
          'stroke-dasharray: 2 5'
        else
          ''
        end
      end

      def add_transition_tooltip(transition_node, transition)
        tooltip = transition_tooltip(transition)
        return unless tooltip

        title = transition_node.add_element('title')
        title.text = tooltip
        add_html_tooltip_attributes(transition_node, tooltip)
      end

      def add_html_tooltip_attributes(node, tooltip)
        return unless @html_tooltips

        node.add_attribute('data-tooltip', tooltip.to_s)
        node.add_attribute('aria-label', tooltip.to_s)
        node.add_attribute('tabindex', '0')
      end

      def transition_link_container(transition_node, transition)
        url = transition_url(transition)
        return transition_node unless url

        transition_node.add_element('a', {
                                      'href' => url.to_s,
                                      'target' => '_blank',
                                      'rel' => 'noopener noreferrer'
                                    })
      end

      def transition_url(transition)
        metadata = transition[:metadata]
        return nil unless metadata.is_a?(Hash)

        metadata[:url] || metadata['url'] || metadata[:href] || metadata['href']
      end

      def transition_tooltip(transition)
        metadata = transition[:metadata]
        if metadata.is_a?(Hash)
          tooltip = metadata[:tooltip] || metadata['tooltip'] || metadata[:description] || metadata['description']
          return tooltip if tooltip
        end

        return nil unless @label_tooltips

        transition[:label].to_s
      end

      def highlighted_transition?(transition)
        @highlight_transitions.any? do |target|
          transition_highlight_match?(transition, target)
        end
      end

      def transition_highlight_match?(transition, target)
        case target
        when Hash
          transition_match_value?(transition, target, :from) &&
            transition_match_value?(transition, target, :to) &&
            transition_match_value?(transition, target, :label)
        when Array
          transition[:from] == target[0] &&
            transition[:to] == target[1] &&
            (target.size < 3 || transition[:label].to_s == target[2].to_s)
        else
          false
        end
      end

      def transition_match_value?(transition, target, key)
        return true unless target.key?(key) || target.key?(key.to_s)

        value = target.key?(key) ? target[key] : target[key.to_s]
        transition[key].to_s == value.to_s
      end

      def unique_svg_id(base_id)
        @element_id_counts[base_id] += 1
        return base_id if @element_id_counts[base_id] == 1

        "#{base_id}-#{@element_id_counts[base_id]}"
      end

      def svg_id_component(value)
        component = value.to_s.downcase.gsub(/[^a-z0-9_-]+/, '-').gsub(/\A-+|-+\z/, '')
        component.empty? ? 'item' : component
      end

      def state_position(state_name)
        @positions[state_name]
      end

      def forward_direction?(x1, y1, x2, y2)
        case @direction
        when :lr
          x2 >= x1
        when :rl
          x2 <= x1
        when :tb
          y2 >= y1
        when :bt
          y2 <= y1
        else
          true
        end
      end

      def vertical_direction?
        @direction == :tb || @direction == :bt
      end
    end
  end
end
