# frozen_string_literal: true

require 'rexml/document'

class Graphomaton
  module Exporters
    class Svg
      STATE_RADIUS = 40
      STATE_INNER_RADIUS = 32

      def initialize(automaton)
        @automaton = automaton
      end

      def export(width = 800, height = 600)
        @automaton.auto_layout(width, height)

        doc = REXML::Document.new
        svg = doc.add_element('svg', {
                                'xmlns' => 'http://www.w3.org/2000/svg',
                                'width' => width.to_s,
                                'height' => height.to_s,
                                'viewBox' => "0 0 #{width} #{height}"
                              })

        add_defs(svg)
        add_style(svg)
        add_transitions(svg)
        add_initial_arrow(svg) if @automaton.initial_state
        add_states(svg)

        doc.to_s
      end

      private

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
        available_width = STATE_RADIUS * 1.7

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
        marker = defs.add_element('marker', {
                                    'id' => 'arrowhead',
                                    'markerWidth' => '10',
                                    'markerHeight' => '10',
                                    'refX' => '9',
                                    'refY' => '3',
                                    'orient' => 'auto'
                                  })
        marker.add_element('polygon', {
                             'points' => '0 0, 10 3, 0 6',
                             'fill' => '#333'
                           })
      end

      def add_style(svg)
        style = svg.add_element('style')
        style.text = <<-CSS
      .state-circle { fill: white; stroke: #333; stroke-width: 2; }
      .final-state { stroke-width: 4; }
      .state-text { font-family: Arial, sans-serif; text-anchor: middle; }
      .transition-line { stroke: #333; stroke-width: 1.5; fill: none; marker-end: url(#arrowhead); }
      .transition-label { font-family: Arial, sans-serif; font-size: 14px; fill: #666; }
      .initial-arrow { stroke: #333; stroke-width: 2; fill: none; marker-end: url(#arrowhead); }
      .label-bg { fill: white; opacity: 0.9; }
        CSS
      end

      def add_transitions(svg)
        processed_pairs = {}
        from_state_indices = {}

        @automaton.transitions.each_with_index do |trans, _idx|
          from_state = @automaton.states[trans[:from]]
          to_state = @automaton.states[trans[:to]]

          if from_state == to_state
            add_self_loop(svg, from_state, trans)
          else
            from_state_indices[trans[:from]] = 0 unless from_state_indices[trans[:from]]
            from_state_index = from_state_indices[trans[:from]]
            from_state_indices[trans[:from]] += 1

            add_transition(svg, from_state, to_state, trans, processed_pairs, from_state_index)
          end
        end
      end

      def add_self_loop(svg, state, trans)
        cx = state[:x]
        cy = state[:y]

        loop_height = 80
        loop_width = 45

        start_angle = -135 * Math::PI / 180
        end_angle = -45 * Math::PI / 180
        radius = STATE_RADIUS

        start_x = cx + (radius * Math.cos(start_angle))
        start_y = cy + (radius * Math.sin(start_angle))
        end_x = cx + (radius * Math.cos(end_angle))
        end_y = cy + (radius * Math.sin(end_angle))

        control1_x = cx - loop_width
        control1_y = cy - loop_height
        control2_x = cx + loop_width
        control2_y = cy - loop_height

        path_d = "M #{start_x} #{start_y} C #{control1_x} #{control1_y}, #{control2_x} #{control2_y}, #{end_x} #{end_y}"

        svg.add_element('path', {
                          'class' => 'transition-line',
                          'd' => path_d
                        })

        text_width = calculate_text_width(trans[:label])
        svg.add_element('rect', {
                          'class' => 'label-bg',
                          'x' => (cx - (text_width / 2)).to_s,
                          'y' => (cy - loop_height - 5).to_s,
                          'width' => text_width.to_s,
                          'height' => '20',
                          'rx' => '3'
                        })

        label = svg.add_element('text', {
                                  'class' => 'transition-label',
                                  'x' => cx.to_s,
                                  'y' => (cy - loop_height + 10).to_s,
                                  'text-anchor' => 'middle'
                                })
        label.text = trans[:label]
      end

      def add_transition(svg, from_state, to_state, trans, processed_pairs, from_state_index)
        x1 = from_state[:x]
        y1 = from_state[:y]
        x2 = to_state[:x]
        y2 = to_state[:y]

        pair_key = [trans[:from], trans[:to]].sort.join('-')
        processed_pairs[pair_key] = 0 unless processed_pairs[pair_key]

        pair_index = processed_pairs[pair_key]
        processed_pairs[pair_key] += 1

        parallel_count = @automaton.count_parallel_transitions(trans[:from], trans[:to])

        dx = x2 - x1
        dy = y2 - y1
        dist = Math.sqrt((dx**2) + (dy**2))

        radius = STATE_RADIUS
        start_x = x1 + ((dx / dist) * radius)
        start_y = y1 + ((dy / dist) * radius)
        end_x = x2 - ((dx / dist) * radius)
        end_y = y2 - ((dy / dist) * radius)

        state_names = @automaton.states.keys
        from_index = state_names.index(trans[:from])
        to_index = state_names.index(trans[:to])

        is_adjacent = (to_index - from_index).abs == 1
        states_between = (to_index - from_index).abs - 1

        if is_adjacent && x1 < x2
          add_straight_line(svg, start_x, start_y, end_x, end_y, trans)
        else
          add_curved_line(svg, start_x, start_y, end_x, end_y, x1, x2, trans, parallel_count, pair_index, states_between, from_state_index)
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

      def add_curved_line(svg, start_x, start_y, end_x, end_y, x1, x2, trans, parallel_count, pair_index, states_between, from_state_index)
        mid_x = (start_x + end_x) / 2
        mid_y = (start_y + end_y) / 2

        base_offset = if states_between > 0
                        (STATE_RADIUS * 1.5) + (states_between * 30) + (from_state_index * 120)
                      else
                        STATE_RADIUS * 2
                      end

        curve_offset = if parallel_count > 1
                         if trans[:from] < trans[:to]
                           -(base_offset + (50 * pair_index))
                         else
                           base_offset + (50 * pair_index)
                         end
                       elsif x1 < x2
                         -base_offset
                       else
                         base_offset
                       end

        control_x = if (x2 - x1).abs < 10
                      mid_x + (50 * (pair_index.even? ? 1 : -1))
                    else
                      mid_x
                    end
        control_y = mid_y + curve_offset

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
        text_width = calculate_text_width(text)
        svg.add_element('rect', {
                          'class' => 'label-bg',
                          'x' => (x - (text_width / 2)).to_s,
                          'y' => (y - 10).to_s,
                          'width' => text_width.to_s,
                          'height' => '20',
                          'rx' => '3'
                        })

        label = svg.add_element('text', {
                                  'class' => 'transition-label',
                                  'x' => x.to_s,
                                  'y' => (y + 5).to_s,
                                  'text-anchor' => 'middle'
                                })
        label.text = text
      end

      def add_initial_arrow(svg)
        init = @automaton.states[@automaton.initial_state]
        return unless init

        svg.add_element('line', {
                          'class' => 'initial-arrow',
                          'x1' => (init[:x] - 60).to_s,
                          'y1' => init[:y].to_s,
                          'x2' => (init[:x] - 30).to_s,
                          'y2' => init[:y].to_s
                        })

        start_label = svg.add_element('text', {
                                        'class' => 'transition-label',
                                        'x' => (init[:x] - 70).to_s,
                                        'y' => (init[:y] - 10).to_s,
                                        'text-anchor' => 'end'
                                      })
        start_label.text = 'start'
      end

      def add_states(svg)
        @automaton.states.each do |name, state|
          circle_class = 'state-circle'
          circle_class += ' final-state' if @automaton.final_states.include?(name)

          svg.add_element('circle', {
                            'class' => circle_class,
                            'cx' => state[:x].to_s,
                            'cy' => state[:y].to_s,
                            'r' => STATE_RADIUS.to_s
                          })

          if @automaton.final_states.include?(name)
            svg.add_element('circle', {
                              'class' => 'state-circle',
                              'cx' => state[:x].to_s,
                              'cy' => state[:y].to_s,
                              'r' => STATE_INNER_RADIUS.to_s
                            })
          end

          font_size = calculate_state_font_size(name.to_s)
          text = svg.add_element('text', {
                                   'class' => 'state-text',
                                   'x' => state[:x].to_s,
                                   'y' => (state[:y] + (font_size * 0.35)).to_s,
                                   'font-size' => font_size.to_s
                                 })
          text.text = name.to_s
        end
      end
    end
  end
end
