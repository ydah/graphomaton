# frozen_string_literal: true

require_relative 'graphomaton/exporters'
require_relative 'graphomaton/version'

class Graphomaton
  class ValidationError < StandardError; end

  STATE_RADIUS = 40
  DEFAULT_STATE_RADIUS = STATE_RADIUS
  DEFAULT_PADDING = 80
  DEFAULT_NODE_SPACING = 120
  DEFAULT_RANK_SPACING = 120
  DEFAULT_FORCE_ITERATIONS = 120
  LAYOUT_OPTIONS = %i[linear circle grid layered bfs force manual].freeze
  DIRECTION_OPTIONS = %i[lr tb rl bt].freeze
  INITIAL_POSITION_OPTIONS = %i[auto start].freeze
  FINAL_POSITION_OPTIONS = %i[auto end].freeze
  FORMAT_OPTIONS = %i[svg png html mermaid mmd dot plantuml puml].freeze
  FORMAT_ALIASES = {
    mmd: :mermaid,
    puml: :plantuml
  }.freeze
  DEFAULT_INITIAL_POSITION = :auto
  DEFAULT_FINAL_POSITION = :auto
  attr_accessor :states, :transitions, :initial_state, :final_states

  def self.png_available?(converter: Exporters::Png::DEFAULT_CONVERTER)
    Exporters::Png.available?(converter: converter)
  end

  def initialize
    @states = {}
    @transitions = []
    @initial_state = nil
    @final_states = []
    @state_positions = {}
    @manual_states = {}
  end

  def add_state(name, x = nil, y = nil, label: nil, style: nil, metadata: nil)
    @manual_states[name] = !x.nil? && !y.nil?
    state = { name: name, x: x, y: y }
    state[:label] = label unless label.nil?
    state[:style] = style unless style.nil?
    state[:metadata] = metadata unless metadata.nil?
    @states[name] = state
    name
  end

  def add_transition(from, to, label, style: nil, metadata: nil)
    transition = { from: from, to: to, label: normalize_transition_label(label) }
    transition[:style] = style unless style.nil?
    transition[:metadata] = metadata unless metadata.nil?
    @transitions << transition
  end

  def set_initial(state)
    @initial_state = state
  end

  def add_final(state)
    @final_states << state unless @final_states.include?(state)
  end

  def validation_errors
    errors = []
    errors << "Initial state #{@initial_state.inspect} is not defined" if @initial_state && !@states.key?(@initial_state)

    @final_states.each do |state|
      errors << "Final state #{state.inspect} is not defined" unless @states.key?(state)
    end

    @transitions.each_with_index do |transition, index|
      from = transition[:from]
      to = transition[:to]
      errors << "Transition #{index} source #{from.inspect} is not defined" unless @states.key?(from)
      errors << "Transition #{index} target #{to.inspect} is not defined" unless @states.key?(to)
    end

    errors
  end

  def valid?
    validation_errors.empty?
  end

  def validate!
    errors = validation_errors
    return true if errors.empty?

    raise ValidationError, errors.join("\n")
  end

  def reachable_states
    layered_distances.keys
  end

  def unreachable_states
    @states.keys - reachable_states
  end

  def layout_positions(width = 800, height = 600, layout: :linear, direction: :lr,
                      state_radius: DEFAULT_STATE_RADIUS, padding: DEFAULT_PADDING,
                      node_spacing: DEFAULT_NODE_SPACING, rank_spacing: DEFAULT_RANK_SPACING,
                      force_iterations: DEFAULT_FORCE_ITERATIONS, layout_seed: nil,
                      initial_position: DEFAULT_INITIAL_POSITION, final_position: DEFAULT_FINAL_POSITION)
    return {} if @states.empty?

    resolved_layout = resolve_layout(layout)
    resolved_direction = resolve_direction(direction)
    resolved_initial_position = resolve_initial_position(initial_position)
    resolved_final_position = resolve_final_position(final_position)
    resolved_padding = [padding.to_f, 0].max
    resolved_node_spacing = [node_spacing.to_f, (state_radius * 2.5)].max
    resolved_rank_spacing = [rank_spacing.to_f, (state_radius * 2.5)].max
    ordered_states = ordered_state_names

    manual_positions = {}
    auto_states = []

    ordered_states.each do |name|
      state = @states[name]
      if manual_position?(name)
        manual_positions[name] = { x: state[:x], y: state[:y] }
      else
        auto_states << name
      end
    end

    auto_states = arrange_auto_states(
      auto_states,
      initial_position: resolved_initial_position,
      final_position: resolved_final_position
    )

    auto_positions = case resolved_layout
                    when :linear
                      layout_linear_positions(auto_states, width, height, resolved_direction, state_radius,
                                             resolved_padding, resolved_node_spacing)
                    when :circle
                      layout_circle_positions(auto_states, width, height, resolved_direction, state_radius, resolved_padding)
                    when :grid
                      layout_grid_positions(auto_states, width, height, resolved_direction, state_radius,
                                           resolved_padding, resolved_node_spacing)
                    when :layered, :bfs
                      layout_layered_positions(auto_states, width, height, resolved_direction, state_radius,
                                              resolved_padding, resolved_node_spacing, resolved_rank_spacing,
                                              final_position: resolved_final_position)
                    when :manual
                      if auto_states.empty?
                        {}
                      else
                        raise ArgumentError, "Manual layout requires explicit coordinates for: #{auto_states.join(', ')}"
                      end
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
                 force_iterations: DEFAULT_FORCE_ITERATIONS, layout_seed: nil,
                 initial_position: DEFAULT_INITIAL_POSITION, final_position: DEFAULT_FINAL_POSITION)
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
      layout_seed: layout_seed,
      initial_position: initial_position,
      final_position: final_position
    ).each do |name, position|
      state = @states[name]
      next if manual_position?(name)

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
                              rank_spacing = DEFAULT_RANK_SPACING, final_position: DEFAULT_FINAL_POSITION)
    return {} if auto_states.empty?

    layer_groups = layout_layered_groups(auto_states, final_position: final_position)
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

  def layout_layered_groups(auto_states, final_position: DEFAULT_FINAL_POSITION)
    return {} if auto_states.empty?
    distances = layered_distances
    return {} if distances.empty?

    resolved_final_position = resolve_final_position(final_position)
    groups = Hash.new { |hash, key| hash[key] = [] }
    auto_states.each do |name|
      next unless distances.key?(name)

      groups[distances[name]] << name
    end

    unreachable_states = auto_states.reject { |name| distances.key?(name) }
    if unreachable_states.any?
      max_depth = distances.values.max || 0
      weak_components(unreachable_states).each_with_index do |component, index|
        groups[max_depth + 1 + index].concat(component)
      end
    end

    return groups unless resolved_final_position == :end

    final_states = auto_states.select { |name| @final_states.include?(name) }
    return groups if final_states.empty?

    groups.each_value do |states|
      states.reject! { |name| @final_states.include?(name) }
    end

    final_layer = (groups.keys.max || 0) + 1
    groups[final_layer] = []
    auto_states.each do |name|
      groups[final_layer] << name if @final_states.include?(name)
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

  def render(format: :svg, width: 800, height: 600, **options)
    case resolve_format(format)
    when :svg
      to_svg(width, height, **options)
    when :png
      to_png(width, height, **options)
    when :html
      to_html(**options)
    when :mermaid
      to_mermaid(**options)
    when :dot
      to_dot(**options)
    when :plantuml
      to_plantuml(**options)
    end
  end

  def save(filename, format: nil, width: 800, height: 600, **options)
    resolved_format = resolve_format(format || File.extname(filename).delete_prefix('.'))

    case resolved_format
    when :svg
      save_svg(filename, width, height, **options)
    when :png
      save_png(filename, width, height, **options)
    when :html
      save_html(filename, **options)
    when :mermaid
      File.write(filename, to_mermaid(**options))
    when :dot
      save_dot(filename, **options)
    when :plantuml
      save_plantuml(filename, **options)
    end
  end

  def to_svg(width = 800, height = 600, theme: Exporters::Svg::DEFAULT_THEME,
             layout: :linear, direction: :lr, responsive: false, state_radius: DEFAULT_STATE_RADIUS,
             padding: DEFAULT_PADDING, node_spacing: DEFAULT_NODE_SPACING, rank_spacing: DEFAULT_RANK_SPACING,
             force_iterations: DEFAULT_FORCE_ITERATIONS, layout_seed: nil, auto_size: false,
             arrow_size: Exporters::Svg::DEFAULT_ARROW_SIZE,
             initial_position: DEFAULT_INITIAL_POSITION, final_position: DEFAULT_FINAL_POSITION,
             merge_parallel_transitions: true, wrap: Exporters::Svg::DEFAULT_WRAP,
             max_transition_label_width: Exporters::Svg::DEFAULT_MAX_LABEL_WIDTH, state_wrap: false,
             max_state_label_width: Exporters::Svg::DEFAULT_MAX_STATE_LABEL_WIDTH,
             label_background: Exporters::Svg::DEFAULT_LABEL_BACKGROUND,
             label_border: Exporters::Svg::DEFAULT_LABEL_BORDER,
             label_padding: Exporters::Svg::DEFAULT_LABEL_PADDING,
             highlight_unreachable: false,
             highlight_transitions: Exporters::Svg::DEFAULT_HIGHLIGHT_TRANSITIONS,
             xml_declaration: Exporters::Svg::DEFAULT_XML_DECLARATION,
             loop_position: Exporters::Svg::DEFAULT_LOOP_POSITION,
             edge_style: Exporters::Svg::DEFAULT_EDGE_STYLE,
             title: nil, description: nil)
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
      auto_size: auto_size,
      arrow_size: arrow_size,
      initial_position: initial_position,
      final_position: final_position,
      merge_parallel_transitions: merge_parallel_transitions,
      label_background: label_background,
      label_border: label_border,
      label_padding: label_padding,
      highlight_unreachable: highlight_unreachable,
      highlight_transitions: highlight_transitions,
      xml_declaration: xml_declaration,
      loop_position: loop_position,
      edge_style: edge_style,
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
               force_iterations: DEFAULT_FORCE_ITERATIONS, layout_seed: nil, auto_size: false,
               arrow_size: Exporters::Svg::DEFAULT_ARROW_SIZE,
               initial_position: DEFAULT_INITIAL_POSITION, final_position: DEFAULT_FINAL_POSITION,
               merge_parallel_transitions: true, wrap: Exporters::Svg::DEFAULT_WRAP,
               max_transition_label_width: Exporters::Svg::DEFAULT_MAX_LABEL_WIDTH, state_wrap: false,
               max_state_label_width: Exporters::Svg::DEFAULT_MAX_STATE_LABEL_WIDTH,
               label_background: Exporters::Svg::DEFAULT_LABEL_BACKGROUND,
               label_border: Exporters::Svg::DEFAULT_LABEL_BORDER,
               label_padding: Exporters::Svg::DEFAULT_LABEL_PADDING,
               highlight_unreachable: false,
               highlight_transitions: Exporters::Svg::DEFAULT_HIGHLIGHT_TRANSITIONS,
               xml_declaration: Exporters::Svg::DEFAULT_XML_DECLARATION,
               loop_position: Exporters::Svg::DEFAULT_LOOP_POSITION,
               edge_style: Exporters::Svg::DEFAULT_EDGE_STYLE,
               title: nil, description: nil)
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
        auto_size: auto_size,
        arrow_size: arrow_size,
        initial_position: initial_position,
        final_position: final_position,
        merge_parallel_transitions: merge_parallel_transitions,
        label_background: label_background,
        label_border: label_border,
        label_padding: label_padding,
        highlight_unreachable: highlight_unreachable,
        highlight_transitions: highlight_transitions,
        xml_declaration: xml_declaration,
        loop_position: loop_position,
        edge_style: edge_style,
        wrap: wrap,
        max_transition_label_width: max_transition_label_width,
        state_wrap: state_wrap,
        max_state_label_width: max_state_label_width,
        title: title,
        description: description
      )
    )
  end

  def to_png(width = 800, height = 600, theme: Exporters::Svg::DEFAULT_THEME,
             scale: Exporters::Png::DEFAULT_SCALE, converter: Exporters::Png::DEFAULT_CONVERTER, **svg_options)
    Exporters::Png.new(self).export(width, height, theme: theme, scale: scale, converter: converter, **svg_options)
  end

  def save_png(filename, width = 800, height = 600, theme: Exporters::Svg::DEFAULT_THEME,
               scale: Exporters::Png::DEFAULT_SCALE, converter: Exporters::Png::DEFAULT_CONVERTER, **svg_options)
    File.binwrite(filename, to_png(width, height, theme: theme, scale: scale, converter: converter, **svg_options))
  end

  def to_mermaid(direction: Exporters::Mermaid::DEFAULT_DIRECTION)
    Exporters::Mermaid.new(self, direction: direction).export
  end

  def to_html(direction: Exporters::Mermaid::DEFAULT_DIRECTION, theme: Exporters::Mermaid::DEFAULT_THEME,
              cdn: Exporters::Mermaid::DEFAULT_CDN, inline_mermaid: false, offline: false, title: nil,
              lang: Exporters::Mermaid::DEFAULT_LANG, show_source: Exporters::Mermaid::DEFAULT_SHOW_SOURCE)
    Exporters::Mermaid.new(self, direction: direction).export_html(
      theme: theme,
      cdn: cdn,
      inline_mermaid: inline_mermaid,
      offline: offline,
      title: title,
      lang: lang,
      show_source: show_source
    )
  end

  def save_html(filename, direction: Exporters::Mermaid::DEFAULT_DIRECTION, theme: Exporters::Mermaid::DEFAULT_THEME,
                cdn: Exporters::Mermaid::DEFAULT_CDN, inline_mermaid: false, offline: false, title: nil,
                lang: Exporters::Mermaid::DEFAULT_LANG, show_source: Exporters::Mermaid::DEFAULT_SHOW_SOURCE)
    File.write(
      filename,
      to_html(
        direction: direction,
        theme: theme,
        cdn: cdn,
        inline_mermaid: inline_mermaid,
        offline: offline,
        title: title,
        lang: lang,
        show_source: show_source
      )
    )
  end

  def to_dot(direction: Exporters::Dot::DEFAULT_DIRECTION, theme: nil)
    Exporters::Dot.new(self, direction: direction, theme: theme).export
  end

  def save_dot(filename, direction: Exporters::Dot::DEFAULT_DIRECTION, theme: nil)
    File.write(filename, to_dot(direction: direction, theme: theme))
  end

  def to_plantuml(direction: Exporters::Plantuml::DEFAULT_DIRECTION, theme: nil)
    Exporters::Plantuml.new(self, direction: direction, theme: theme).export
  end

  def save_plantuml(filename, direction: Exporters::Plantuml::DEFAULT_DIRECTION, theme: nil)
    File.write(filename, to_plantuml(direction: direction, theme: theme))
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

  def resolve_initial_position(initial_position)
    resolved = initial_position.to_sym
    return resolved if INITIAL_POSITION_OPTIONS.include?(resolved)

    raise ArgumentError, "Unknown initial_position: #{initial_position.inspect}. Available values: #{INITIAL_POSITION_OPTIONS.join(', ')}"
  end

  def resolve_final_position(final_position)
    resolved = final_position.to_sym
    return resolved if FINAL_POSITION_OPTIONS.include?(resolved)

    raise ArgumentError, "Unknown final_position: #{final_position.inspect}. Available values: #{FINAL_POSITION_OPTIONS.join(', ')}"
  end

  def resolve_format(format)
    resolved = format.to_s.delete_prefix('.').to_sym
    resolved = FORMAT_ALIASES.fetch(resolved, resolved)
    return resolved if FORMAT_OPTIONS.include?(resolved)

    raise ArgumentError, "Unknown format: #{format.inspect}. Available formats: #{FORMAT_OPTIONS.join(', ')}"
  end

  def normalize_transition_label(label)
    return label.map(&:to_s).uniq.join(', ') if label.is_a?(Array)

    label
  end

  def arrange_auto_states(auto_states, initial_position:, final_position:)
    ordered = auto_states.uniq

    if initial_position == :start && @initial_state && ordered.include?(@initial_state)
      ordered.delete(@initial_state)
      ordered.unshift(@initial_state)
    end

    return ordered unless final_position == :end

    non_final_states = ordered.reject { |name| @final_states.include?(name) }
    final_states = ordered.select { |name| @final_states.include?(name) }
    non_final_states + final_states
  end

  def manual_position?(state)
    @manual_states[state]
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
