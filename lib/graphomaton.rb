# frozen_string_literal: true

require_relative 'graphomaton/exporters'
require_relative 'graphomaton/version'

class Graphomaton
  STATE_RADIUS = 40
  DEFAULT_STATE_RADIUS = STATE_RADIUS
  DEFAULT_PADDING = 80
  DEFAULT_NODE_SPACING = 120
  DEFAULT_RANK_SPACING = 120
  DEFAULT_FORCE_ITERATIONS = 120
  LAYOUT_OPTIONS = %i[linear circle grid layered force].freeze
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

  def layout_positions(width = 800, height = 600, layout: :linear, direction: :lr,
                      state_radius: DEFAULT_STATE_RADIUS, padding: DEFAULT_PADDING,
                      node_spacing: DEFAULT_NODE_SPACING, rank_spacing: DEFAULT_RANK_SPACING,
                      force_iterations: DEFAULT_FORCE_ITERATIONS, layout_seed: nil)
    return {} if @states.empty?

    resolved_layout = resolve_layout(layout)
    resolved_direction = resolve_direction(direction)
    resolved_padding = [padding.to_f, 0].max
    resolved_node_spacing = [node_spacing.to_f, (state_radius * 2.5)].max
    resolved_rank_spacing = [rank_spacing.to_f, (state_radius * 2.5)].max
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
                      layout_linear_positions(auto_states, width, height, resolved_direction, state_radius,
                                             resolved_padding, resolved_node_spacing)
                    when :circle
                      layout_circle_positions(auto_states, width, height, resolved_direction, state_radius, resolved_padding)
                    when :grid
                      layout_grid_positions(auto_states, width, height, resolved_direction, state_radius,
                                           resolved_padding, resolved_node_spacing)
                    when :layered
                      layout_layered_positions(auto_states, width, height, resolved_direction, state_radius,
                                              resolved_padding, resolved_node_spacing, resolved_rank_spacing)
                    when :force
                      layout_force_positions(
                        auto_states,
                        width,
                        height,
                        resolved_direction,
                        state_radius,
                        resolved_padding,
                        resolved_node_spacing,
                        force_iterations,
                        layout_seed
                      )
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

  def auto_layout(width = 800, height = 600, layout: :linear, direction: :lr,
                 state_radius: DEFAULT_STATE_RADIUS, padding: DEFAULT_PADDING,
                 node_spacing: DEFAULT_NODE_SPACING, rank_spacing: DEFAULT_RANK_SPACING,
                 force_iterations: DEFAULT_FORCE_ITERATIONS, layout_seed: nil)
    return if @states.empty?

    layout_positions(
      width,
      height,
      layout: layout,
      direction: direction,
      state_radius: state_radius,
      padding: padding,
      node_spacing: node_spacing,
      rank_spacing: rank_spacing,
      force_iterations: force_iterations,
      layout_seed: layout_seed
    ).each do |name, position|
      state = @states[name]
      next unless state[:x].nil? || state[:y].nil?

      state[:x] = position[:x]
      state[:y] = position[:y]
    end
  end

  def layout_linear_positions(auto_states, width, height, direction, state_radius = DEFAULT_STATE_RADIUS,
                             padding = DEFAULT_PADDING, node_spacing = DEFAULT_NODE_SPACING)
    return {} if auto_states.empty?

    margin = [padding, state_radius + 20].max
    available_x = [width - (2 * margin), 0].max.to_f
    available_y = [height - (2 * margin), 0].max.to_f
    count = auto_states.size
    horizontal_step = count > 1 ? [available_x / (count - 1), node_spacing].min : 0
    vertical_step = count > 1 ? [available_y / (count - 1), node_spacing].min : 0

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

  def layout_circle_positions(auto_states, width, height, direction, state_radius = DEFAULT_STATE_RADIUS,
                             padding = DEFAULT_PADDING)
    return {} if auto_states.empty?

    count = auto_states.size
    ordered = (direction == :rl || direction == :bt) ? auto_states.reverse : auto_states
    center_x = width / 2.0
    center_y = height / 2.0
    margin = [padding, state_radius + 20].max
    max_radius = [width, height].min / 2.0 - margin - state_radius
    radius = [max_radius, state_radius + 20].max
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

  def layout_grid_positions(auto_states, width, height, direction, state_radius = DEFAULT_STATE_RADIUS,
                           padding = DEFAULT_PADDING, node_spacing = DEFAULT_NODE_SPACING)
    return {} if auto_states.empty?

    count = auto_states.size
    columns = Math.sqrt(count).ceil
    rows = [(count.to_f / columns).ceil, 1].max.to_i

    margin = [padding, state_radius + 20].max
    available_x = [width - (2 * margin), 0].max.to_f
    available_y = [height - (2 * margin), 0].max.to_f
    horizontal_step = columns > 1 ? [available_x / (columns - 1), node_spacing].min : 0
    vertical_step = rows > 1 ? [available_y / (rows - 1), node_spacing].min : 0

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

  def layout_layered_positions(auto_states, width, height, direction, state_radius = DEFAULT_STATE_RADIUS,
                              padding = DEFAULT_PADDING, node_spacing = DEFAULT_NODE_SPACING,
                              rank_spacing = DEFAULT_RANK_SPACING)
    return {} if auto_states.empty?

    layer_groups = layout_layered_groups(auto_states)
    return layout_linear_positions(auto_states, width, height, direction, state_radius, padding, node_spacing) if layer_groups.empty?

    margin = [padding, state_radius + 20].max
    available_x = [width - (2 * margin), 0].max.to_f
    available_y = [height - (2 * margin), 0].max.to_f
    layers = layer_groups.keys
    layer_count = layers.size

    positions = {}
    layers = layers.sort_by do |depth|
      depth.to_i
    end

    layers.each_with_index do |layer, layer_index|
      states = layer_groups[layer] || []
      state_count = states.size
      next if state_count.zero?

      if direction == :lr || direction == :rl
        x = if layer_count > 1
              margin + (rank_spacing * layer_index)
            else
              width / 2.0
            end
        x = width - margin - ((rank_spacing * layer_index)) if direction == :rl && layer_count > 1
        x = [x, width - margin].min if direction == :rl
        x = [margin, x].max
        y_step = state_count > 1 ? [available_y / (state_count + 1), node_spacing].min : 0

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
              margin + (rank_spacing * layer_index)
            else
              height / 2.0
            end
        y = height - margin - (rank_spacing * layer_index) if direction == :bt && layer_count > 1
        y = [y, height - margin].min if direction == :bt
        y = [margin, y].max
        x_step = state_count > 1 ? [available_x / (state_count + 1), node_spacing].min : 0

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
    distances = layered_distances
    return {} if distances.empty?

    groups = Hash.new { |hash, key| hash[key] = [] }
    ordered_state_names.each do |name|
      next unless auto_states.include?(name)
      next unless distances.key?(name)

      groups[distances[name]] << name
    end

    unreachable_states = auto_states.reject { |name| distances.key?(name) }
    return groups if unreachable_states.empty?

    max_depth = distances.values.max || 0
    weak_components(unreachable_states).each_with_index do |component, index|
      groups[max_depth + 1 + index].concat(component)
    end

    groups
  end

  def weak_components(states)
    return [] if states.empty?

    remaining = states.to_h { |state| [state, true] }
    adjacency = Hash.new { |hash, key| hash[key] = [] }

    @transitions.each do |trans|
      from = trans[:from]
      to = trans[:to]
      next unless remaining.key?(from) && remaining.key?(to)

      adjacency[from] << to
      adjacency[to] << from
    end

    components = []
    while (seed = remaining.keys.first)
      stack = [seed]
      component = []

      until stack.empty?
        state = stack.pop
        next unless remaining.delete(state)

        component << state
        adjacency[state].each do |next_state|
          next unless remaining.key?(next_state)

          stack << next_state
        end
      end

      components << component
    end

    components
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

  def layout_force_positions(auto_states, width, height, direction, state_radius = DEFAULT_STATE_RADIUS,
                            padding = DEFAULT_PADDING, node_spacing = DEFAULT_NODE_SPACING,
                            force_iterations = DEFAULT_FORCE_ITERATIONS, layout_seed = nil)
    return {} if auto_states.empty?

    iterations = [force_iterations.to_i, 0].max
    return {} if width <= 0 || height <= 0

    positions = {}
    count = auto_states.size
    center_x = width / 2.0
    center_y = height / 2.0
    radius = [width, height].min / 4.0
    radius = [radius, node_spacing].min if radius > 0

    auto_states.each_with_index do |name, index|
      if count == 1
        x = center_x
        y = center_y
      else
        offset_ratio = count > 1 ? (index.to_f / (count - 1)) : 0.5

        case direction
        when :lr
          x = padding + (offset_ratio * (width - (2 * padding)))
          y = center_y
        when :rl
          x = width - padding - (offset_ratio * (width - (2 * padding)))
          y = center_y
        when :tb
          x = center_x
          y = padding + (offset_ratio * (height - (2 * padding)))
        when :bt
          x = center_x
          y = height - padding - (offset_ratio * (height - (2 * padding)))
        else
          angle = (2 * Math::PI * index) / count
          x = center_x + (Math.cos(angle) * radius)
          y = center_y + (Math.sin(angle) * radius)
        end
      end

      positions[name] = { x: x.to_f, y: y.to_f }
    end

    return positions if iterations.zero?

    rng = layout_seed ? Random.new(layout_seed.to_i) : nil

    if rng
      positions.each_value do |position|
        position[:x] += (rng.rand - 0.5) * 10
        position[:y] += (rng.rand - 0.5) * 10
      end
    end

    manual_positions = @states.each_with_object({}) do |(name, state), hash|
      hash[name] = { x: state[:x], y: state[:y] } if state[:x] && state[:y]
    end

    k = [node_spacing, 1.0].max
    attraction_coeff = 0.01
    repulsion_coeff = (k * k)
    max_displacement = [width, height].min * 0.05

    iterations.times do |step|
      forces = auto_states.to_h do |name|
        [name, { x: 0.0, y: 0.0 }]
      end

      auto_states.combination(2) do |name_a, name_b|
        a = positions[name_a]
        b = positions[name_b]
        next unless a && b

        delta_x = a[:x] - b[:x]
        delta_y = a[:y] - b[:y]
        distance = Math.sqrt((delta_x * delta_x) + (delta_y * delta_y))
        distance = 1.0 if distance <= 0.0

        force = repulsion_coeff / distance
        nx = delta_x / distance
        ny = delta_y / distance

        forces[name_a][:x] += nx * force
        forces[name_a][:y] += ny * force
        forces[name_b][:x] -= nx * force
        forces[name_b][:y] -= ny * force
      end

      manual_positions.each do |_, fixed|
        fixed_x = fixed[:x].to_f
        fixed_y = fixed[:y].to_f

        auto_states.each do |name|
          current = positions[name]
          next unless current

          delta_x = current[:x] - fixed_x
          delta_y = current[:y] - fixed_y
          distance = Math.sqrt((delta_x * delta_x) + (delta_y * delta_y))
          distance = 1.0 if distance <= 0.0

          force = repulsion_coeff / distance
          nx = delta_x / distance
          ny = delta_y / distance

          forces[name][:x] += nx * force
          forces[name][:y] += ny * force
        end
      end

      @transitions.each do |transition|
        from = transition[:from]
        to = transition[:to]

        from_point = positions[from] || manual_positions[from]
        to_point = positions[to] || manual_positions[to]
        next unless from_point && to_point

        delta_x = to_point[:x] - from_point[:x]
        delta_y = to_point[:y] - from_point[:y]
        distance = Math.sqrt((delta_x * delta_x) + (delta_y * delta_y))
        distance = 1.0 if distance <= 0.0

        force = (distance * distance) / k
        nx = delta_x / distance
        ny = delta_y / distance

        if positions.key?(from)
          forces[from][:x] -= nx * force * attraction_coeff
          forces[from][:y] -= ny * force * attraction_coeff
        end

        if positions.key?(to)
          forces[to][:x] += nx * force * attraction_coeff
          forces[to][:y] += ny * force * attraction_coeff
        end
      end

      damping = 1.0 - (step.to_f / (iterations + 1).to_f)
      max_move = max_displacement * damping

      positions.each_key do |name|
        current = positions[name]
        force = forces[name]
        next unless current && force

        next_x = current[:x] + force[:x].clamp(-max_move, max_move)
        next_y = current[:y] + force[:y].clamp(-max_move, max_move)

        next_x = [[next_x, padding].max, width - padding].min
        next_y = [[next_y, padding].max, height - padding].min

        current[:x] = next_x
        current[:y] = next_y
      end
    end

    positions
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
             layout: :linear, direction: :lr, responsive: false, state_radius: DEFAULT_STATE_RADIUS,
             padding: DEFAULT_PADDING, node_spacing: DEFAULT_NODE_SPACING, rank_spacing: DEFAULT_RANK_SPACING,
             force_iterations: DEFAULT_FORCE_ITERATIONS, layout_seed: nil,
             merge_parallel_transitions: true, wrap: Exporters::Svg::DEFAULT_WRAP,
             max_transition_label_width: Exporters::Svg::DEFAULT_MAX_LABEL_WIDTH, state_wrap: false,
             max_state_label_width: Exporters::Svg::DEFAULT_MAX_STATE_LABEL_WIDTH, title: nil, description: nil)
    Exporters::Svg.new(self).export(
      width,
      height,
      theme: theme,
      layout: layout,
      direction: direction,
      responsive: responsive,
      state_radius: state_radius,
      padding: padding,
      node_spacing: node_spacing,
      rank_spacing: rank_spacing,
      force_iterations: force_iterations,
      layout_seed: layout_seed,
      merge_parallel_transitions: merge_parallel_transitions,
      wrap: wrap,
      max_transition_label_width: max_transition_label_width,
      state_wrap: state_wrap,
      max_state_label_width: max_state_label_width,
      title: title,
      description: description
    )
  end

  def save_svg(filename, width = 800, height = 600, theme: Exporters::Svg::DEFAULT_THEME,
               layout: :linear, direction: :lr, responsive: false, state_radius: DEFAULT_STATE_RADIUS,
               padding: DEFAULT_PADDING, node_spacing: DEFAULT_NODE_SPACING, rank_spacing: DEFAULT_RANK_SPACING,
               force_iterations: DEFAULT_FORCE_ITERATIONS, layout_seed: nil,
               merge_parallel_transitions: true, wrap: Exporters::Svg::DEFAULT_WRAP,
               max_transition_label_width: Exporters::Svg::DEFAULT_MAX_LABEL_WIDTH, state_wrap: false,
               max_state_label_width: Exporters::Svg::DEFAULT_MAX_STATE_LABEL_WIDTH, title: nil, description: nil)
    File.write(
      filename,
      to_svg(
        width,
        height,
        theme: theme,
        layout: layout,
        direction: direction,
        responsive: responsive,
        state_radius: state_radius,
        padding: padding,
        node_spacing: node_spacing,
        rank_spacing: rank_spacing,
        force_iterations: force_iterations,
        layout_seed: layout_seed,
        merge_parallel_transitions: merge_parallel_transitions,
        wrap: wrap,
        max_transition_label_width: max_transition_label_width,
        state_wrap: state_wrap,
        max_state_label_width: max_state_label_width,
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

  def to_html(direction: Exporters::Mermaid::DEFAULT_DIRECTION, theme: Exporters::Mermaid::DEFAULT_THEME,
              cdn: Exporters::Mermaid::DEFAULT_CDN, inline_mermaid: false, offline: false, title: nil, lang: Exporters::Mermaid::DEFAULT_LANG)
    Exporters::Mermaid.new(self, direction: direction).export_html(
      theme: theme,
      cdn: cdn,
      inline_mermaid: inline_mermaid,
      offline: offline,
      title: title,
      lang: lang
    )
  end

  def save_html(filename, direction: Exporters::Mermaid::DEFAULT_DIRECTION, theme: Exporters::Mermaid::DEFAULT_THEME,
                cdn: Exporters::Mermaid::DEFAULT_CDN, inline_mermaid: false, offline: false, title: nil, lang: Exporters::Mermaid::DEFAULT_LANG)
    File.write(
      filename,
      to_html(
        direction: direction,
        theme: theme,
        cdn: cdn,
        inline_mermaid: inline_mermaid,
        offline: offline,
        title: title,
        lang: lang
      )
    )
  end

  def to_dot(direction: Exporters::Dot::DEFAULT_DIRECTION)
    Exporters::Dot.new(self, direction: direction).export
  end

  def save_dot(filename, direction: Exporters::Dot::DEFAULT_DIRECTION)
    File.write(filename, to_dot(direction: direction))
  end

  def to_plantuml(direction: Exporters::Plantuml::DEFAULT_DIRECTION)
    Exporters::Plantuml.new(self, direction: direction).export
  end

  def save_plantuml(filename, direction: Exporters::Plantuml::DEFAULT_DIRECTION)
    File.write(filename, to_plantuml(direction: direction))
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
