# frozen_string_literal: true

require 'rexml/document'
require_relative 'graphomaton/version'

class Graphomaton
  attr_accessor :states, :transitions, :initial_state, :final_states

  def initialize
    @states = {}
    @transitions = []
    @initial_state = nil
    @final_states = []
    @state_positions = {}
  end

  def add_state(name, x = nil, y = nil)
    @states[name] = { name: name, x: x, y: y }
    name
  end

  def add_transition(from, to, label)
    @transitions << { from: from, to: to, label: label }
  end

  def set_initial(state)
    @initial_state = state
  end

  def add_final(state)
    @final_states << state unless @final_states.include?(state)
  end

  def auto_layout(width = 800, height = 600)
    return if @states.empty?

    ordered_states = []
    ordered_states << @initial_state if @initial_state && @states[@initial_state]

    @states.each_key do |name|
      ordered_states << name unless ordered_states.include?(name)
    end

    margin = 100
    spacing = (width - (2 * margin)) / [ordered_states.size - 1, 1].max
    y_center = height / 2

    ordered_states.each_with_index do |name, index|
      if @states[name][:x].nil? || @states[name][:y].nil?
        @states[name][:x] = margin + (index * spacing)
        @states[name][:y] = y_center
      end
    end
  end

  def count_parallel_transitions(from, to)
    count = 0
    @transitions.each do |trans|
      if (trans[:from] == from && trans[:to] == to) ||
         (trans[:from] == to && trans[:to] == from)
        count += 1
      end
    end
    count
  end

  def get_transition_index(from, to, label)
    index = 0
    @transitions.each do |trans|
      next unless (trans[:from] == from && trans[:to] == to) ||
                  (trans[:from] == to && trans[:to] == from)
      return index if trans[:from] == from && trans[:to] == to && trans[:label] == label

      index += 1
    end
    index
  end

  def to_svg(width = 800, height = 600)
    auto_layout(width, height)

    doc = REXML::Document.new
    svg = doc.add_element('svg', {
                            'xmlns' => 'http://www.w3.org/2000/svg',
                            'width' => width.to_s,
                            'height' => height.to_s,
                            'viewBox' => "0 0 #{width} #{height}"
                          })

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

    style = svg.add_element('style')
    style.text = <<-CSS
      .state-circle { fill: white; stroke: #333; stroke-width: 2; }
      .final-state { stroke-width: 4; }
      .state-text { font-family: Arial, sans-serif; font-size: 16px; text-anchor: middle; }
      .transition-line { stroke: #333; stroke-width: 1.5; fill: none; marker-end: url(#arrowhead); }
      .transition-label { font-family: Arial, sans-serif; font-size: 14px; fill: #666; }
      .initial-arrow { stroke: #333; stroke-width: 2; fill: none; marker-end: url(#arrowhead); }
      .label-bg { fill: white; opacity: 0.9; }
    CSS

    processed_pairs = {}

    @transitions.each_with_index do |trans, _idx|
      from_state = @states[trans[:from]]
      to_state = @states[trans[:to]]

      if from_state == to_state

        cx = from_state[:x]
        cy = from_state[:y]

        loop_height = 80
        loop_width = 45

        start_angle = -135 * Math::PI / 180
        end_angle = -45 * Math::PI / 180
        radius = 30

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

        text_width = (trans[:label].length * 8) + 10
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
      else
        x1 = from_state[:x]
        y1 = from_state[:y]
        x2 = to_state[:x]
        y2 = to_state[:y]

        pair_key = [trans[:from], trans[:to]].sort.join('-')
        processed_pairs[pair_key] = 0 unless processed_pairs[pair_key]

        pair_index = processed_pairs[pair_key]
        processed_pairs[pair_key] += 1

        parallel_count = count_parallel_transitions(trans[:from], trans[:to])

        dx = x2 - x1
        dy = y2 - y1
        dist = Math.sqrt((dx**2) + (dy**2))

        radius = 30
        start_x = x1 + ((dx / dist) * radius)
        start_y = y1 + ((dy / dist) * radius)
        end_x = x2 - ((dx / dist) * radius)
        end_y = y2 - ((dy / dist) * radius)

        state_names = @states.keys
        from_index = state_names.index(trans[:from])
        to_index = state_names.index(trans[:to])

        is_adjacent = (to_index - from_index).abs == 1

        if is_adjacent && x1 < x2

          svg.add_element('line', {
                            'class' => 'transition-line',
                            'x1' => start_x.to_s,
                            'y1' => start_y.to_s,
                            'x2' => end_x.to_s,
                            'y2' => end_y.to_s
                          })

          label_x = (start_x + end_x) / 2
          label_y = ((start_y + end_y) / 2) - 10
        else

          mid_x = (start_x + end_x) / 2
          mid_y = (start_y + end_y) / 2
          curve_offset = if parallel_count > 1

                           if trans[:from] < trans[:to]

                             -40 * (pair_index + 1)
                           else

                             40 * (pair_index + 1)
                           end
                         elsif x1 < x2

                           -30
                         else
                           30
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
        end

        text_width = (trans[:label].length * 8) + 10
        svg.add_element('rect', {
                          'class' => 'label-bg',
                          'x' => (label_x - (text_width / 2)).to_s,
                          'y' => (label_y - 10).to_s,
                          'width' => text_width.to_s,
                          'height' => '20',
                          'rx' => '3'
                        })

        label = svg.add_element('text', {
                                  'class' => 'transition-label',
                                  'x' => label_x.to_s,
                                  'y' => (label_y + 5).to_s,
                                  'text-anchor' => 'middle'
                                })
      end
      label.text = trans[:label]
    end

    if @initial_state && @states[@initial_state]
      init = @states[@initial_state]
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

    @states.each do |name, state|
      circle_class = 'state-circle'
      circle_class += ' final-state' if @final_states.include?(name)

      svg.add_element('circle', {
                        'class' => circle_class,
                        'cx' => state[:x].to_s,
                        'cy' => state[:y].to_s,
                        'r' => '30'
                      })

      if @final_states.include?(name)
        svg.add_element('circle', {
                          'class' => 'state-circle',
                          'cx' => state[:x].to_s,
                          'cy' => state[:y].to_s,
                          'r' => '24'
                        })
      end

      text = svg.add_element('text', {
                               'class' => 'state-text',
                               'x' => state[:x].to_s,
                               'y' => (state[:y] + 5).to_s
                             })
      text.text = name.to_s
    end

    doc.to_s
  end

  def save_svg(filename, width = 800, height = 600)
    File.write(filename, to_svg(width, height))
  end
end
