# frozen_string_literal: true

require 'rexml/document'

class Graphomaton
  module Exporters
    class Svg
      DEFAULT_STATE_RADIUS = 40
      DEFAULT_THEME = :light
      DEFAULT_LAYOUT = :linear
      DEFAULT_DIRECTION = :lr
      DEFAULT_MERGE_PARALLEL_TRANSITIONS = true
      DEFAULT_WRAP = false
      DEFAULT_LABEL_BACKGROUND = true
      DEFAULT_HIGHLIGHT_UNREACHABLE = false
      DEFAULT_XML_DECLARATION = false
      DEFAULT_LOOP_POSITION = :auto
      DEFAULT_PADDING = 80
      DEFAULT_NODE_SPACING = 120
      DEFAULT_RANK_SPACING = 120
      DEFAULT_FORCE_ITERATIONS = 120
      DEFAULT_ARROW_SIZE = 10
      DEFAULT_INITIAL_POSITION = :auto
      DEFAULT_FINAL_POSITION = :auto
      DEFAULT_AUTO_SIZE = false
      DEFAULT_MAX_LABEL_WIDTH = 120
      DEFAULT_STATE_WRAP = false
      DEFAULT_MAX_STATE_LABEL_WIDTH = 120
      LAYOUT_OPTIONS = %i[linear circle grid layered bfs force manual].freeze
      DIRECTION_OPTIONS = %i[lr tb rl bt].freeze
      LOOP_POSITION_OPTIONS = %i[auto top right bottom left].freeze

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
        }
      }.freeze

      def initialize(automaton)
        @automaton = automaton
        @state_radius = DEFAULT_STATE_RADIUS
      end

      def export(width = 800, height = 600, theme: DEFAULT_THEME, layout: DEFAULT_LAYOUT, direction: DEFAULT_DIRECTION, responsive: false,
                 state_radius: DEFAULT_STATE_RADIUS, wrap: DEFAULT_WRAP, max_transition_label_width: DEFAULT_MAX_LABEL_WIDTH,
                 state_wrap: DEFAULT_STATE_WRAP, max_state_label_width: DEFAULT_MAX_STATE_LABEL_WIDTH,
                 padding: DEFAULT_PADDING, node_spacing: DEFAULT_NODE_SPACING, rank_spacing: DEFAULT_RANK_SPACING,
                 force_iterations: DEFAULT_FORCE_ITERATIONS, layout_seed: nil, auto_size: DEFAULT_AUTO_SIZE,
                 arrow_size: DEFAULT_ARROW_SIZE,
                 initial_position: DEFAULT_INITIAL_POSITION, final_position: DEFAULT_FINAL_POSITION,
                 merge_parallel_transitions: DEFAULT_MERGE_PARALLEL_TRANSITIONS,
                 label_background: DEFAULT_LABEL_BACKGROUND,
                 highlight_unreachable: DEFAULT_HIGHLIGHT_UNREACHABLE,
                 xml_declaration: DEFAULT_XML_DECLARATION,
                 loop_position: DEFAULT_LOOP_POSITION,
                 title: nil, description: nil)
        @state_radius = state_radius.to_f
        @arrow_size = [arrow_size.to_f, 1.0].max
        @theme = resolve_theme(theme)
        @layout = resolve_layout(layout)
        @direction = resolve_direction(direction)
        @loop_position = resolve_loop_position(loop_position)
        @merge_parallel_transitions = merge_parallel_transitions
        @label_background = label_background
        @highlight_unreachable = highlight_unreachable
        @unreachable_states = @highlight_unreachable ? @automaton.unreachable_states : []
        @padding = padding
        @node_spacing = node_spacing
        @rank_spacing = rank_spacing
        @force_iterations = force_iterations
        @layout_seed = layout_seed
        @wrap_labels = wrap
        @state_wrap = state_wrap
        @max_state_label_width = max_state_label_width
        @max_transition_label_width = max_transition_label_width
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
          final_position: final_position
        )
        if auto_size
          width, height = auto_size_canvas(width, height)
        end
        @label_boxes = []
        @title_text = title
        @description_text = description
        @svg_id = "graphomaton-#{object_id}"
        @element_id_counts = Hash.new(0)

        doc = REXML::Document.new
        svg = doc.add_element('svg', svg_root_attributes(width, height, responsive: responsive))

        add_defs(svg)
        add_style(svg)
        add_accessibility_metadata(svg)
        add_background(svg, width, height)
        transition_group = svg.add_element('g', { 'class' => 'transitions' })
        state_group = svg.add_element('g', { 'class' => 'states' })
        add_transitions(transition_group)
        add_initial_arrow(transition_group) if @automaton.initial_state
        add_states(state_group)

        svg_output = doc.to_s
        return svg_output unless xml_declaration

        %(<?xml version="1.0" encoding="UTF-8"?>\n#{svg_output})
      end

      private

      def resolve_theme(theme)
        return normalize_theme(theme) if theme.is_a?(Hash)

        theme_name = theme.to_s.to_sym
        THEMES.fetch(theme_name)
      rescue KeyError
        available_themes = THEMES.keys.join(', ')
        raise ArgumentError, "Unknown SVG theme: #{theme.inspect}. Available themes: #{available_themes}"
      end

      def normalize_theme(theme)
        normalized = theme.transform_keys { |key| key.to_sym }
        unknown = normalized.keys - THEMES.fetch(DEFAULT_THEME).keys
        return merge_themes(normalized) if unknown.empty?

        raise ArgumentError, "Unknown SVG theme keys: #{unknown.join(', ')}"
      end

      def merge_themes(overrides)
        THEMES.fetch(DEFAULT_THEME).merge(overrides)
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

      def calculate_text_width(text)
        ascii_chars = text.chars.count { |c| c.ascii_only? }
        non_ascii_chars = text.length - ascii_chars

        width = (ascii_chars * 8) + (non_ascii_chars * 16) + 20
        [width, 60].max
      end

      def calculate_state_font_size(name)
        ascii_chars = name.chars.count { |c| c.ascii_only? }
        non_ascii_chars = name.length - ascii_chars

        estimated_width = (ascii_chars * 0.55) + (non_ascii_chars * 0.9)
        available_width = (@state_radius || DEFAULT_STATE_RADIUS) * 1.7

        base_size = 20
        calculated_size = if estimated_width * base_size > available_width
                            (available_width / estimated_width).floor
                          else
                            base_size
                          end

        [calculated_size, 12].max
      end

      def add_defs(svg)
        defs = svg.add_element('defs')
        marker_height = @arrow_size * 0.6
        marker = defs.add_element('marker', {
                                    'id' => 'arrowhead',
                                    'markerWidth' => @arrow_size.to_s,
                                    'markerHeight' => marker_height.to_s,
                                    'refX' => (@arrow_size * 0.9).to_s,
                                    'refY' => (marker_height / 2).to_s,
                                    'orient' => 'auto',
                                    'markerUnits' => 'strokeWidth'
                                  })
        marker.add_element('polygon', {
                             'points' => "0 0, #{@arrow_size} #{marker_height / 2}, 0 #{marker_height}",
                             'fill' => @theme[:stroke]
                           })
      end

      def add_style(svg)
        style = svg.add_element('style')
        background = @theme[:background] || 'transparent'
        style.text = <<-CSS
      .diagram-background { fill: #{background}; }
      .state-circle { fill: #{@theme[:state_fill]}; stroke: #{@theme[:stroke]}; stroke-width: 2; vector-effect: non-scaling-stroke; shape-rendering: geometricPrecision; }
      .final-state { stroke-width: 4; }
      .state-text { font-family: Arial, sans-serif; text-anchor: middle; fill: #{@theme[:state_text]}; text-rendering: geometricPrecision; }
      .transition-line { stroke: #{@theme[:stroke]}; stroke-width: 1.5; fill: none; marker-end: url(#arrowhead); vector-effect: non-scaling-stroke; shape-rendering: geometricPrecision; stroke-linecap: round; stroke-linejoin: round; }
      .transition-label { font-family: Arial, sans-serif; font-size: 14px; fill: #{@theme[:transition_label]}; text-rendering: geometricPrecision; }
      .initial-arrow { stroke: #{@theme[:stroke]}; stroke-width: 2; fill: none; marker-end: url(#arrowhead); vector-effect: non-scaling-stroke; shape-rendering: geometricPrecision; stroke-linecap: round; stroke-linejoin: round; }
      .label-bg { fill: #{@theme[:label_background]}; opacity: #{@theme[:label_opacity]}; }
      .unreachable-state { opacity: 0.45; }
        CSS
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
        labels.uniq.join(', ')
      end

      def add_self_loop(svg, state, trans, loop_index = 0)
        transition_node = svg.add_element('g', transition_group_attributes(trans))
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

        transition_node.add_element('path', {
                                      'class' => 'transition-line',
                                      'd' => path_d
                                    })

        text_width = calculate_text_width(trans[:label])
        label_y_shift = loop_offset * (loop_index.odd? ? -1 : 1)
        if @label_background
          transition_node.add_element('rect', {
                                        'class' => 'label-bg',
                                        'x' => (cx + loop_specs[:label_offset][:x] - (text_width / 2)).to_s,
                                        'y' => (cy + loop_specs[:label_offset][:y] - 5 + label_y_shift).to_s,
                                        'width' => text_width.to_s,
                                        'height' => '20',
                                        'rx' => '3'
                                      })
        end

        label = transition_node.add_element('text', {
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

        if is_adjacent && forward_direction?(x1, y1, x2, y2)
          add_straight_line(transition_node, start_x, start_y, end_x, end_y, trans)
        else
          add_curved_line(
            transition_node,
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
        svg.add_element('line', {
                          'class' => 'transition-line',
                          'x1' => start_x.to_s,
                          'y1' => start_y.to_s,
                          'x2' => end_x.to_s,
                          'y2' => end_y.to_s
                        })

        label_x = (start_x + end_x) / 2
        label_y = ((start_y + end_y) / 2) - 10

        add_label(svg, label_x, label_y, trans[:label])
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

        svg.add_element('path', {
                          'class' => 'transition-line',
                          'd' => path_d
                        })

        t = 0.5
        label_x = ((1 - t) * (1 - t) * start_x) + (2 * (1 - t) * t * control_x) + (t * t * end_x)
        label_y = ((1 - t) * (1 - t) * start_y) + (2 * (1 - t) * t * control_y) + (t * t * end_y)

        add_label(svg, label_x, label_y, trans[:label])
      end

      def add_label(svg, x, y, text)
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

        if @label_background
          svg.add_element('rect', {
                            'class' => 'label-bg',
                            'x' => box[:x].to_s,
                            'y' => box[:y].to_s,
                            'width' => box[:width].to_s,
                            'height' => box[:height].to_s,
                            'rx' => '3'
                          })
        end

        label = svg.add_element('text', {
                                  'class' => 'transition-label',
                                  'x' => (box[:x] + (box[:width] / 2)).to_s,
                                  'y' => (box[:y] + 12).to_s,
                                  'text-anchor' => 'middle'
                                })
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

        initial_node.add_element('line', {
                                   'class' => 'initial-arrow',
                                   'x1' => (init[:x] - 60).to_s,
                                   'y1' => init[:y].to_s,
                                   'x2' => (init[:x] - 30).to_s,
                                   'y2' => init[:y].to_s
                                 })

        start_label = initial_node.add_element('text', {
                                                'class' => 'transition-label',
                                                'x' => (init[:x] - 70).to_s,
                                                'y' => (init[:y] - 10).to_s,
                                                'text-anchor' => 'end'
                                              })
        start_label.text = 'start'
      end

      def add_states(svg)
        @automaton.states.each do |name, state|
          lines = state_label_lines(name)
          position = state_position(name) || state
          state_node = svg.add_element('g', state_group_attributes(name))
          circle_class = 'state-circle'
          circle_class += ' final-state' if @automaton.final_states.include?(name)

          state_node.add_element('circle', {
                                   'class' => circle_class,
                                   'cx' => position[:x].to_s,
                                   'cy' => position[:y].to_s,
                                   'r' => @state_radius.to_s
                                 })

          if @automaton.final_states.include?(name)
            inner_radius = [@state_radius - 8, 8].max
            state_node.add_element('circle', {
                                     'class' => 'state-circle',
                                     'cx' => position[:x].to_s,
                                     'cy' => position[:y].to_s,
                                     'r' => inner_radius.to_s
                                   })
          end

          font_size = calculate_state_font_size(name.to_s)
          if lines.size == 1
            text = state_node.add_element('text', {
                                            'class' => 'state-text',
                                            'x' => position[:x].to_s,
                                            'y' => (position[:y] + (font_size * 0.35)).to_s,
                                            'font-size' => font_size.to_s
                                          })
            text.text = lines.first
          else
            line_gap = font_size + 2
            text_start_y = position[:y].to_f - ((lines.size - 1) * line_gap / 2.0) + (line_gap * 0.35)
            text = state_node.add_element('text', {
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

      def state_group_attributes(name)
        classes = ['state']
        classes << 'unreachable-state' if @unreachable_states.include?(name)

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
        {
          'class' => 'transition',
          'id' => unique_svg_id(
            "transition-#{svg_id_component(from)}-#{svg_id_component(to)}-#{svg_id_component(label)}"
          ),
          'data-from' => from.to_s,
          'data-to' => to.to_s,
          'data-label' => label.to_s
        }
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
