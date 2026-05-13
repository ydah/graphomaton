# frozen_string_literal: true

require_relative 'graphomaton/exporters'
require_relative 'graphomaton/version'

class Graphomaton
  STATE_RADIUS = 40
  LAYOUT_OPTIONS = %i[linear circle grid layered].freeze
  DIRECTION_OPTIONS = %i[lr tb rl bt].freeze
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

  def layout_positions(width = 800, height = 600, layout: :linear, direction: :lr)
    return {} if @states.empty?

    resolved_layout = resolve_layout(layout)
    resolved_direction = resolve_direction(direction)
    ordered_states = ordered_state_names

    manual_positions = {}
    auto_states = []

    ordered_states.each do |name|
      state = @states[name]
      if manual_position?(state)
        manual_positions[name] = { x: state[:x], y: state[:y] }
      else
        auto_states << name
      end
    end

    auto_positions = case resolved_layout
                    when :linear
                      layout_linear_positions(auto_states, width, height, resolved_direction)
                    when :circle
                      layout_circle_positions(auto_states, width, height, resolved_direction)
                    when :grid
                      layout_grid_positions(auto_states, width, height, resolved_direction)
                    when :layered
                      layout_layered_positions(auto_states, width, height, resolved_direction)
                    else
                      raise ArgumentError, "Unknown SVG layout: #{layout.inspect}. Available layouts: #{LAYOUT_OPTIONS.join(', ')}"
                    end

    positions = manual_positions.merge(auto_positions)
    @state_positions = positions
    positions
  end

  def ordered_state_names
    ordered_states = []
    ordered_states << @initial_state if @initial_state && @states[@initial_state]

    @states.each_key do |name|
      ordered_states << name unless ordered_states.include?(name)
    end

    ordered_states
  end

  def auto_layout(width = 800, height = 600, layout: :linear, direction: :lr)
    return if @states.empty?

    layout_positions(width, height, layout: layout, direction: direction).each do |name, position|
      state = @states[name]
      next unless state[:x].nil? || state[:y].nil?

      state[:x] = position[:x]
      state[:y] = position[:y]
    end
  end

  def layout_linear_positions(auto_states, width, height, direction)
    return {} if auto_states.empty?

    margin = 80
    available_x = [width - (2 * margin), 0].max.to_f
    available_y = [height - (2 * margin), 0].max.to_f
    count = auto_states.size
    horizontal_step = (count > 1 ? available_x / (count - 1) : 0)
    vertical_step = (count > 1 ? available_y / (count - 1) : 0)

    positions = {}
    auto_states.each_with_index do |name, index|
      positions[name] = layout_linear_position(
        index,
        count,
        width.to_f,
        height.to_f,
        margin,
        horizontal_step,
        vertical_step,
        direction
      )
    end

    positions
  end

  def layout_circle_positions(auto_states, width, height, direction)
    return {} if auto_states.empty?

    count = auto_states.size
    ordered = (direction == :rl || direction == :bt) ? auto_states.reverse : auto_states
    center_x = width / 2.0
    center_y = height / 2.0
    margin = 80
    max_radius = [width, height].min / 2.0 - margin - STATE_RADIUS
    radius = [max_radius, STATE_RADIUS + 20].max
    angle_start = case direction
                  when :tb then 0.0
                  when :bt then Math::PI
                  else
                    -Math::PI / 2.0
                  end
    angle_step = (2 * Math::PI) / count

    positions = {}
    ordered.each_with_index do |name, index|
      angle = angle_start + (angle_step * index)
      positions[name] = {
        x: center_x + (radius * Math.cos(angle)),
        y: center_y + (radius * Math.sin(angle))
      }
    end

    positions
  end

  def layout_grid_positions(auto_states, width, height, direction)
    return {} if auto_states.empty?

    count = auto_states.size
    columns = Math.sqrt(count).ceil
    rows = [(count.to_f / columns).ceil, 1].max.to_i

    margin = 80
    available_x = [width - (2 * margin), 0].max.to_f
    available_y = [height - (2 * margin), 0].max.to_f
    horizontal_step = (columns > 1 ? available_x / (columns - 1) : 0)
    vertical_step = (rows > 1 ? available_y / (rows - 1) : 0)

    positions = {}
    auto_states.each_with_index do |name, index|
      if direction == :tb || direction == :bt
        row = index % rows
        column = index / rows
        y = if direction == :tb
              margin + (row * vertical_step)
            else
              height - margin - (row * vertical_step)
            end
      else
        row = index / columns
        column = index % columns
        y = margin + (row * vertical_step)
      end

      x = if direction == :rl
            width - margin - (column * horizontal_step)
          else
            margin + (column * horizontal_step)
          end

      positions[name] = { x: x, y: y }
    end

    positions
  end

  def layout_layered_positions(auto_states, width, height, direction)
    return {} if auto_states.empty?

    layer_groups = layout_layered_groups(auto_states)
    return layout_linear_positions(auto_states, width, height, direction) if layer_groups.empty?

    margin = 80
    available_x = [width - (2 * margin), 0].max.to_f
    available_y = [height - (2 * margin), 0].max.to_f
    layers = layer_groups.keys.sort
    layer_count = layers.size

    positions = {}
    layers.each_with_index do |layer, layer_index|
      states = layer_groups[layer] || []
      state_count = states.size
      next if state_count.zero?

      if direction == :lr || direction == :rl
        x = if layer_count > 1
              margin + (available_x * layer_index / (layer_count - 1))
            else
              width / 2.0
            end
        x = width - margin - ((available_x * layer_index) / (layer_count - 1)) if direction == :rl && layer_count > 1
        y_step = (state_count > 1 ? available_y / (state_count + 1) : 0)

        states.each_with_index do |name, state_index|
          y = if state_count > 1
                margin + ((state_index + 1) * y_step)
              else
                height / 2.0
              end
          positions[name] = { x: x, y: y }
        end
      else
        y = if layer_count > 1
              margin + (available_y * layer_index / (layer_count - 1))
            else
              height / 2.0
            end
        y = height - margin - ((available_y * layer_index) / (layer_count - 1)) if direction == :bt && layer_count > 1
        x_step = (state_count > 1 ? available_x / (state_count + 1) : 0)

        states.each_with_index do |name, state_index|
          x = if state_count > 1
                margin + ((state_index + 1) * x_step)
              else
                width / 2.0
              end
          positions[name] = { x: x, y: y }
        end
      end
    end

    positions
  end

  def layout_layered_groups(auto_states)
    return {} if auto_states.empty?
    return {} unless @initial_state && @states[@initial_state]

    distances = layered_distances
    return {} if distances.empty?

    groups = {}
    ordered_state_names.each do |name|
      next unless auto_states.include?(name)

      depth = distances[name] || Float::INFINITY
      (groups[depth] ||= []) << name
    end

    groups
  end

  def layered_distances
    return {} unless @initial_state && @states[@initial_state]

    adjacency = Hash.new { |hash, key| hash[key] = [] }
    @transitions.each do |trans|
      adjacency[trans[:from]] << trans[:to]
    end

    distances = {}
    queue = [@initial_state]
    distances[@initial_state] = 0

    until queue.empty?
      current = queue.shift
      adjacency[current].each do |next_state|
        next if distances.key?(next_state)

        distances[next_state] = distances[current] + 1
        queue << next_state
      end
    end

    distances
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

  def to_svg(width = 800, height = 600, theme: Exporters::Svg::DEFAULT_THEME,
             layout: :linear, direction: :lr, responsive: false,
             merge_parallel_transitions: true, wrap: Exporters::Svg::DEFAULT_WRAP,
             max_transition_label_width: Exporters::Svg::DEFAULT_MAX_LABEL_WIDTH, title: nil, description: nil)
    Exporters::Svg.new(self).export(
      width,
      height,
      theme: theme,
      layout: layout,
      direction: direction,
      responsive: responsive,
      merge_parallel_transitions: merge_parallel_transitions,
      wrap: wrap,
      max_transition_label_width: max_transition_label_width,
      title: title,
      description: description
    )
  end

  def save_svg(filename, width = 800, height = 600, theme: Exporters::Svg::DEFAULT_THEME,
               layout: :linear, direction: :lr, responsive: false,
               merge_parallel_transitions: true, wrap: Exporters::Svg::DEFAULT_WRAP,
               max_transition_label_width: Exporters::Svg::DEFAULT_MAX_LABEL_WIDTH, title: nil, description: nil)
    File.write(
      filename,
      to_svg(
        width,
        height,
        theme: theme,
        layout: layout,
        direction: direction,
        responsive: responsive,
        merge_parallel_transitions: merge_parallel_transitions,
        wrap: wrap,
        max_transition_label_width: max_transition_label_width,
        title: title,
        description: description
      )
    )
  end

  def to_png(width = 800, height = 600, theme: Exporters::Svg::DEFAULT_THEME)
    Exporters::Png.new(self).export(width, height, theme: theme)
  end

  def save_png(filename, width = 800, height = 600, theme: Exporters::Svg::DEFAULT_THEME)
    File.binwrite(filename, to_png(width, height, theme: theme))
  end

  def to_mermaid(direction: Exporters::Mermaid::DEFAULT_DIRECTION)
    Exporters::Mermaid.new(self, direction: direction).export
  end

  def save_html(filename, direction: Exporters::Mermaid::DEFAULT_DIRECTION)
    File.write(filename, to_mermaid(direction: direction))
  end

  def to_dot(direction: Exporters::Dot::DEFAULT_DIRECTION)
    Exporters::Dot.new(self, direction: direction).export
  end

  def save_dot(filename, direction: Exporters::Dot::DEFAULT_DIRECTION)
    File.write(filename, to_dot(direction: direction))
  end

  def to_plantuml
    Exporters::Plantuml.new(self).export
  end

  def save_plantuml(filename)
    File.write(filename, to_plantuml)
  end

  private

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

  def manual_position?(state)
    return false unless state

    !state[:x].nil? && !state[:y].nil?
  end

  def layout_linear_position(index, _count, width, height, margin, horizontal_step, vertical_step, direction)
    case direction
    when :lr
      x = margin + (index * horizontal_step)
      y = height / 2.0
    when :rl
      x = width - margin - (index * horizontal_step)
      y = height / 2.0
    when :tb
      x = width / 2.0
      y = margin + (index * vertical_step)
    when :bt
      x = width / 2.0
      y = height - margin - (index * vertical_step)
    end

    { x: x, y: y }
  end
end
