# frozen_string_literal: true

require 'json'
require 'open3'
require 'shellwords'
require 'yaml'

require_relative 'graphomaton/exporters'
require_relative 'graphomaton/version'

class Graphomaton
  class ValidationError < StandardError; end

  class Theme
    def self.default
      Exporters::Svg::THEMES.fetch(Exporters::Svg::DEFAULT_THEME)
    end

    def self.available_names
      Exporters::Svg::THEMES.keys
    end

    def self.normalize(theme, context: 'Graphomaton theme')
      raise ArgumentError, "#{context} must be a Hash" unless theme.is_a?(Hash)

      normalized = theme.transform_keys { |key| key.to_sym }
      unknown = normalized.keys - default.keys
      raise ArgumentError, "Unknown #{context} keys: #{unknown.join(', ')}" unless unknown.empty?

      default.merge(normalized)
    end

    def self.resolve(theme, context: 'Graphomaton theme', allow_auto: false)
      return normalize(theme, context: context) if theme.is_a?(Hash)

      theme_name = theme.to_s.to_sym
      return default if allow_auto && theme_name == :auto

      Exporters::Svg::THEMES.fetch(theme_name)
    rescue KeyError
      available = available_names
      available = available + [:auto] if allow_auto
      raise ArgumentError, "Unknown #{context}: #{theme.inspect}. Available themes: #{available.join(', ')}"
    end

    def self.gallery_html(title: 'Graphomaton Theme Gallery', themes: Exporters::Svg::THEMES, animated: false)
      cards = themes.map do |name, theme|
        normalized = normalize(theme)
        theme_card(name, normalized)
      end.join("\n")

      <<~HTML
        <!DOCTYPE html>
        <html lang="en">
        <head>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <title>#{escape_html(title)}</title>
          <style>
            body { background: #f8fafc; color: #0f172a; font-family: Georgia, serif; margin: 0; padding: 32px; }
            h1 { font-size: clamp(2rem, 4vw, 4rem); margin: 0 0 24px; }
            .theme-gallery { display: grid; gap: 20px; grid-template-columns: repeat(auto-fit, minmax(260px, 1fr)); }
            .theme-card { background: white; border: 1px solid #e2e8f0; border-radius: 18px; box-shadow: 0 18px 40px rgba(15, 23, 42, 0.08); overflow: hidden; }
            .theme-card h2 { font-size: 1rem; letter-spacing: 0.08em; margin: 0; padding: 16px 18px; text-transform: uppercase; }
            .theme-card svg { display: block; width: 100%; }
            #{theme_gallery_animation_css(animated)}
          </style>
        </head>
        <body>
          <h1>#{escape_html(title)}</h1>
          <div class="theme-gallery">
        #{cards}
          </div>
        </body>
        </html>
      HTML
    end

    def self.save_gallery_html(filename, **options)
      File.write(filename, gallery_html(**options))
    end

    def self.theme_card(name, theme)
      background = theme[:background] || '#ffffff'

      <<~HTML
            <article class="theme-card">
              <h2>#{escape_html(name)}</h2>
              <svg viewBox="0 0 260 150" role="img" aria-label="#{escape_html(name)} theme preview" style="background: #{escape_html(background)}">
                <path d="M76 76 C112 32, 148 32, 184 76" fill="none" stroke="#{escape_html(theme[:stroke])}" stroke-width="3" marker-end="url(#arrow-#{escape_html(name)})"/>
                <defs>
                  <marker id="arrow-#{escape_html(name)}" markerWidth="10" markerHeight="6" refX="9" refY="3" orient="auto">
                    <path d="M0 0 L10 3 L0 6 Z" fill="#{escape_html(theme[:stroke])}"/>
                  </marker>
                </defs>
                <circle cx="70" cy="82" r="28" fill="#{escape_html(theme[:state_fill])}" stroke="#{escape_html(theme[:stroke])}" stroke-width="3"/>
                <circle cx="190" cy="82" r="28" fill="#{escape_html(theme[:state_fill])}" stroke="#{escape_html(theme[:stroke])}" stroke-width="3"/>
                <text x="70" y="88" text-anchor="middle" fill="#{escape_html(theme[:state_text])}" font-size="18">A</text>
                <text x="190" y="88" text-anchor="middle" fill="#{escape_html(theme[:state_text])}" font-size="18">B</text>
                <rect x="113" y="42" width="34" height="22" rx="4" fill="#{escape_html(theme[:label_background])}" opacity="#{escape_html(theme[:label_opacity])}"/>
                <text x="130" y="58" text-anchor="middle" fill="#{escape_html(theme[:transition_label])}" font-size="14">a</text>
              </svg>
            </article>
      HTML
    end
    private_class_method :theme_card

    def self.theme_gallery_animation_css(animated)
      return '' unless animated

      <<~CSS
            .theme-card path { animation: graphomaton-gallery-dash 2.4s linear infinite; stroke-dasharray: 12 8; }
            .theme-card circle { animation: graphomaton-gallery-pulse 2.4s ease-in-out infinite; transform-box: fill-box; transform-origin: center; }
            @keyframes graphomaton-gallery-dash {
              to { stroke-dashoffset: -40; }
            }
            @keyframes graphomaton-gallery-pulse {
              0%, 100% { transform: scale(1); }
              50% { transform: scale(1.05); }
            }
            @media (prefers-reduced-motion: reduce) {
              .theme-card path,
              .theme-card circle { animation: none; }
            }
      CSS
    end
    private_class_method :theme_gallery_animation_css

    def self.escape_html(value)
      value.to_s
           .gsub('&', '&amp;')
           .gsub('<', '&lt;')
           .gsub('>', '&gt;')
           .gsub('"', '&quot;')
           .gsub("'", '&#39;')
    end
    private_class_method :escape_html
  end

  STATE_RADIUS = 40
  DEFAULT_STATE_RADIUS = STATE_RADIUS
  DEFAULT_PADDING = 80
  DEFAULT_NODE_SPACING = 120
  DEFAULT_RANK_SPACING = 120
  DEFAULT_FORCE_ITERATIONS = 120
  DEFAULT_GRAPHVIZ_COMMAND = 'dot'
  DEFAULT_PRESERVE_MANUAL_POSITIONS = true
  DEFAULT_FIT = :none
  LAYOUT_OPTIONS = %i[linear circle grid layered bfs force graphviz dot manual].freeze
  DIRECTION_OPTIONS = %i[lr tb rl bt].freeze
  FIT_OPTIONS = %i[none contain cover].freeze
  INITIAL_POSITION_OPTIONS = %i[auto start].freeze
  FINAL_POSITION_OPTIONS = %i[auto end].freeze
  FORMAT_OPTIONS = %i[svg png pdf webp html mermaid mmd dot plantuml puml].freeze
  FORMAT_ALIASES = {
    mmd: :mermaid,
    puml: :plantuml
  }.freeze
  DEFAULT_INITIAL_POSITION = :auto
  DEFAULT_FINAL_POSITION = :auto
  DEFAULT_EPSILON_LABEL = "\u03b5"
  attr_accessor :states, :transitions, :initial_state, :final_states

  def self.png_available?(converter: Exporters::Png::DEFAULT_CONVERTER)
    Exporters::Png.available?(converter: converter)
  end

  def self.pdf_available?(converter: Exporters::Pdf::DEFAULT_CONVERTER)
    Exporters::Pdf.available?(converter: converter)
  end

  def self.webp_available?(converter: Exporters::Webp::DEFAULT_CONVERTER)
    Exporters::Webp.available?(converter: converter)
  end

  def self.from_hash(data)
    raise ArgumentError, 'Graphomaton input must be a Hash' unless data.is_a?(Hash)

    automaton = new
    Array(input_value(data, :states)).each do |state|
      add_state_from_input(automaton, state)
    end

    initial_state = input_value(data, :initial, :initial_state)
    automaton.set_initial(initial_state) unless initial_state.nil?

    Array(input_value(data, :final, :final_states)).each do |state|
      automaton.add_final(state)
    end

    Array(input_value(data, :transitions)).each do |transition|
      add_transition_from_input(automaton, transition)
    end

    automaton
  end

  def self.from_json(source)
    from_hash(JSON.parse(source.respond_to?(:read) ? source.read : source.to_s))
  end

  def self.from_yaml(source)
    yaml = YAML.safe_load(source.respond_to?(:read) ? source.read : source.to_s, permitted_classes: [Symbol], aliases: true)
    from_hash(yaml || {})
  end

  def self.theme_from_hash(data)
    raise ArgumentError, 'Graphomaton theme input must be a Hash' unless data.is_a?(Hash)

    theme = input_value(data, :theme) || data
    Theme.normalize(theme, context: 'Graphomaton theme')
  end

  def self.theme_from_json(source)
    theme_from_hash(JSON.parse(source.respond_to?(:read) ? source.read : source.to_s))
  end

  def self.theme_from_yaml(source)
    yaml = YAML.safe_load(source.respond_to?(:read) ? source.read : source.to_s, permitted_classes: [Symbol], aliases: true)
    theme_from_hash(yaml || {})
  end

  def self.add_state_from_input(automaton, input)
    unless input.is_a?(Hash)
      automaton.add_state(input)
      return
    end

    name = input_value(input, :id, :name)
    raise ArgumentError, 'State input requires id or name' if name.nil?

    automaton.add_state(
      name,
      input_value(input, :x),
      input_value(input, :y),
      label: input_value(input, :label),
      style: input_value(input, :style),
      metadata: input_value(input, :metadata),
      shape: input_value(input, :shape)
    )
    automaton.set_initial(name) if input_value(input, :initial)
    automaton.add_final(name) if input_value(input, :final, :accepting)
  end
  private_class_method :add_state_from_input

  def self.add_transition_from_input(automaton, input)
    if input.is_a?(Array)
      from, to, label = input
      automaton.add_transition(from, to, label)
      return
    end

    raise ArgumentError, 'Transition input must be a Hash or Array' unless input.is_a?(Hash)

    from = input_value(input, :from)
    to = input_value(input, :to)
    label = input_value(input, :label)
    raise ArgumentError, 'Transition input requires from, to, and label' if from.nil? || to.nil? || label.nil?

    automaton.add_transition(
      from,
      to,
      label,
      style: input_value(input, :style),
      metadata: input_value(input, :metadata),
      line_style: input_value(input, :line_style)
    )
  end
  private_class_method :add_transition_from_input

  def self.input_value(hash, *keys)
    keys.each do |key|
      return hash[key] if hash.key?(key)
      return hash[key.to_s] if hash.key?(key.to_s)
    end

    nil
  end
  private_class_method :input_value

  def initialize
    @states = {}
    @transitions = []
    @initial_state = nil
    @final_states = []
    @state_positions = {}
    @manual_states = {}
  end

  def add_state(name, x = nil, y = nil, label: nil, style: nil, metadata: nil, shape: nil)
    @manual_states[name] = !x.nil? && !y.nil?
    state = { name: name, x: x, y: y }
    state[:label] = label unless label.nil?
    state[:style] = style unless style.nil?
    state[:metadata] = metadata unless metadata.nil?
    state[:shape] = shape unless shape.nil?
    @states[name] = state
    name
  end

  def add_transition(from, to, label, style: nil, metadata: nil, line_style: nil,
                     epsilon_label: DEFAULT_EPSILON_LABEL, sort_labels: false)
    transition = { from: from, to: to, label: normalize_transition_label(label, epsilon_label: epsilon_label, sort_labels: sort_labels) }
    transition[:style] = style unless style.nil?
    transition[:metadata] = metadata unless metadata.nil?
    transition[:line_style] = line_style unless line_style.nil?
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

  def states_reaching_final
    defined_final_states = @final_states.select { |state| @states.key?(state) }
    return [] if defined_final_states.empty?

    reverse_edges = Hash.new { |hash, key| hash[key] = [] }
    @transitions.each do |transition|
      from = transition[:from]
      to = transition[:to]
      next unless @states.key?(from) && @states.key?(to)

      reverse_edges[to] << from
    end

    reachable = {}
    queue = defined_final_states.dup
    until queue.empty?
      state = queue.shift
      next if reachable[state]

      reachable[state] = true
      reverse_edges[state].each do |previous|
        queue << previous unless reachable[previous]
      end
    end

    ordered_state_names.select { |state| reachable[state] }
  end

  def dead_states
    reaching_final = states_reaching_final
    return [] if reaching_final.empty?

    @states.keys - reaching_final
  end

  def live_states
    states_reaching_final
  end

  def trap_states
    ordered_state_names.select do |state|
      outgoing = @transitions.select do |transition|
        transition[:from] == state && @states.key?(transition[:to])
      end
      next false if outgoing.empty?

      outgoing.all? { |transition| transition[:to] == state }
    end
  end

  def layout_warnings(width = 800, height = 600, layout: :linear, direction: :lr,
                      state_radius: DEFAULT_STATE_RADIUS, padding: DEFAULT_PADDING,
                      node_spacing: DEFAULT_NODE_SPACING, rank_spacing: DEFAULT_RANK_SPACING,
                      force_iterations: DEFAULT_FORCE_ITERATIONS, layout_seed: nil,
                      graphviz_command: DEFAULT_GRAPHVIZ_COMMAND,
                      initial_position: DEFAULT_INITIAL_POSITION, final_position: DEFAULT_FINAL_POSITION,
                      preserve_manual_positions: DEFAULT_PRESERVE_MANUAL_POSITIONS,
                      fit: DEFAULT_FIT)
    positions = layout_positions(
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
      graphviz_command: graphviz_command,
      initial_position: initial_position,
      final_position: final_position,
      preserve_manual_positions: preserve_manual_positions,
      fit: fit
    )

    canvas_warnings(positions, width, height, state_radius)
  end

  def layout_positions(width = 800, height = 600, layout: :linear, direction: :lr,
                      state_radius: DEFAULT_STATE_RADIUS, padding: DEFAULT_PADDING,
                      node_spacing: DEFAULT_NODE_SPACING, rank_spacing: DEFAULT_RANK_SPACING,
                      force_iterations: DEFAULT_FORCE_ITERATIONS, layout_seed: nil,
                      graphviz_command: DEFAULT_GRAPHVIZ_COMMAND,
                      initial_position: DEFAULT_INITIAL_POSITION, final_position: DEFAULT_FINAL_POSITION,
                      preserve_manual_positions: DEFAULT_PRESERVE_MANUAL_POSITIONS,
                      fit: DEFAULT_FIT)
    return {} if @states.empty?

    resolved_layout = resolve_layout(layout)
    resolved_direction = resolve_direction(direction)
    resolved_fit = resolve_fit(fit)
    resolved_initial_position = resolve_initial_position(initial_position)
    resolved_final_position = resolve_final_position(final_position)
    resolved_padding = [padding.to_f, 0].max
    resolved_node_spacing = [node_spacing.to_f, (state_radius * 2.5)].max
    resolved_rank_spacing = [rank_spacing.to_f, (state_radius * 2.5)].max
    effective_preserve_manual_positions = preserve_manual_positions || resolved_layout == :manual
    ordered_states = ordered_state_names

    manual_positions = {}
    auto_states = []

    ordered_states.each do |name|
      state = @states[name]
      if effective_preserve_manual_positions && manual_position?(name)
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
                    when :graphviz, :dot
                      layout_graphviz_positions(
                        auto_states,
                        width,
                        height,
                        resolved_direction,
                        state_radius,
                        resolved_padding,
                        command: graphviz_command
                      )
                    else
                      raise ArgumentError, "Unknown SVG layout: #{layout.inspect}. Available layouts: #{LAYOUT_OPTIONS.join(', ')}"
                    end

    positions = manual_positions.merge(auto_positions)
    positions = fit_positions(positions, width, height, state_radius, resolved_padding, resolved_fit) unless resolved_fit == :none
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
                 graphviz_command: DEFAULT_GRAPHVIZ_COMMAND,
                 initial_position: DEFAULT_INITIAL_POSITION, final_position: DEFAULT_FINAL_POSITION,
                 preserve_manual_positions: DEFAULT_PRESERVE_MANUAL_POSITIONS,
                 fit: DEFAULT_FIT)
    return if @states.empty?

    resolved_layout = resolve_layout(layout)
    effective_preserve_manual_positions = preserve_manual_positions || resolved_layout == :manual

    layout_positions(
      width,
      height,
      layout: resolved_layout,
      direction: direction,
      state_radius: state_radius,
      padding: padding,
      node_spacing: node_spacing,
      rank_spacing: rank_spacing,
      force_iterations: force_iterations,
      layout_seed: layout_seed,
      graphviz_command: graphviz_command,
      initial_position: initial_position,
      final_position: final_position,
      preserve_manual_positions: effective_preserve_manual_positions,
      fit: fit
    ).each do |name, position|
      state = @states[name]
      next if effective_preserve_manual_positions && manual_position?(name)

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
    layer_groups = crossing_reduced_layer_groups(layer_groups, layers)

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

  def crossing_reduced_layer_groups(layer_groups, layers)
    ordered = {}
    previous_order = nil

    layers.each do |layer|
      states = layer_groups[layer] || []
      ordered[layer] = if previous_order
                         order_layer_by_neighbor_barycenter(states, previous_order, incoming: true)
                       else
                         states
                       end
      previous_order = ordered[layer]
    end

    next_order = nil
    layers.reverse_each do |layer|
      states = ordered[layer] || []
      ordered[layer] = order_layer_by_neighbor_barycenter(states, next_order, incoming: false) if next_order
      next_order = ordered[layer]
    end

    ordered
  end

  def order_layer_by_neighbor_barycenter(states, adjacent_order, incoming:)
    adjacent_index = adjacent_order.each_with_index.to_h
    original_index = states.each_with_index.to_h

    states.sort_by do |name|
      neighbor_positions = layer_neighbor_positions(name, adjacent_index, incoming: incoming)
      if neighbor_positions.empty?
        [1, original_index[name], 0.0]
      else
        average = neighbor_positions.sum.to_f / neighbor_positions.size
        [0, average, original_index[name]]
      end
    end
  end

  def layer_neighbor_positions(name, adjacent_index, incoming:)
    @transitions.filter_map do |transition|
      neighbor = if incoming
                   transition[:from] if transition[:to] == name
                 else
                   transition[:to] if transition[:from] == name
                 end
      adjacent_index[neighbor] if neighbor && adjacent_index.key?(neighbor)
    end
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

  def layout_graphviz_positions(auto_states, width, height, direction, state_radius = DEFAULT_STATE_RADIUS,
                               padding = DEFAULT_PADDING, command: DEFAULT_GRAPHVIZ_COMMAND)
    return {} if auto_states.empty?

    stdout, stderr, status = Open3.capture3(
      *graphviz_command_args(command),
      '-Tplain',
      stdin_data: graphviz_layout_dot(auto_states, direction)
    )

    unless status.success?
      message = stderr.to_s.strip
      message = 'dot exited without a diagnostic' if message.empty?
      raise ArgumentError, "Graphviz layout failed: #{message}"
    end

    normalize_graphviz_positions(
      parse_graphviz_plain_positions(stdout, auto_states),
      width,
      height,
      state_radius,
      padding
    )
  rescue Errno::ENOENT
    raise ArgumentError, "Graphviz layout requires the `#{Array(command).join(' ')}` command"
  end

  def graphviz_layout_dot(auto_states, direction)
    included = auto_states.to_h { |name| [name, true] }
    lines = [
      'digraph graphomaton_layout {',
      "    rankdir=#{graphviz_rankdir(direction)};",
      '    node [shape=circle];'
    ]

    auto_states.each do |name|
      lines << "    \"#{graphviz_escape(name)}\";"
    end

    @transitions.each do |transition|
      from = transition[:from]
      to = transition[:to]
      next unless included[from] && included[to]

      lines << "    \"#{graphviz_escape(from)}\" -> \"#{graphviz_escape(to)}\";"
    end

    lines << '}'
    lines.join("\n")
  end

  def graphviz_command_args(command)
    args = command.is_a?(Array) ? command.map(&:to_s) : Shellwords.split(command.to_s)
    raise ArgumentError, 'Graphviz command cannot be empty' if args.empty?

    args
  end

  def graphviz_rankdir(direction)
    {
      lr: 'LR',
      rl: 'RL',
      tb: 'TB',
      bt: 'BT'
    }.fetch(direction)
  end

  def graphviz_escape(value)
    value.to_s.gsub('\\', '\\\\').gsub('"', '\"')
  end

  def parse_graphviz_plain_positions(output, expected_states)
    positions = {}

    output.each_line do |line|
      tokens = Shellwords.split(line)
      next unless tokens.first == 'node' && tokens.size >= 4

      positions[tokens[1]] = {
        x: Float(tokens[2]),
        y: Float(tokens[3])
      }
    rescue ArgumentError
      next
    end

    missing = expected_states.reject { |name| positions.key?(name) }
    unless missing.empty?
      raise ArgumentError, "Graphviz layout did not return positions for: #{missing.join(', ')}"
    end

    expected_states.to_h { |name| [name, positions[name]] }
  end

  def normalize_graphviz_positions(raw_positions, width, height, state_radius, padding)
    return {} if raw_positions.empty?

    canvas_width = width.to_f
    canvas_height = height.to_f
    margin = [padding.to_f, state_radius.to_f + 20].max
    available_x = [canvas_width - (2 * margin), 0].max
    available_y = [canvas_height - (2 * margin), 0].max
    xs = raw_positions.values.map { |position| position[:x].to_f }
    ys = raw_positions.values.map { |position| position[:y].to_f }
    min_x, max_x = xs.minmax
    min_y, max_y = ys.minmax
    span_x = max_x - min_x
    span_y = max_y - min_y

    if span_x <= 0.0 && span_y <= 0.0
      return raw_positions.to_h do |name, _position|
        [name, { x: canvas_width / 2.0, y: canvas_height / 2.0 }]
      end
    end

    scale_candidates = []
    scale_candidates << (available_x / span_x) if span_x.positive?
    scale_candidates << (available_y / span_y) if span_y.positive?
    scale = scale_candidates.min || 1.0
    graph_width = span_x * scale
    graph_height = span_y * scale
    offset_x = margin + ((available_x - graph_width) / 2.0)
    offset_y = margin + ((available_y - graph_height) / 2.0)

    raw_positions.to_h do |name, position|
      x = if span_x.positive?
            offset_x + ((position[:x].to_f - min_x) * scale)
          else
            canvas_width / 2.0
          end
      y = if span_y.positive?
            offset_y + ((max_y - position[:y].to_f) * scale)
          else
            canvas_height / 2.0
          end

      [name, { x: x, y: y }]
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

  def render(format: :svg, width: 800, height: 600, **options)
    case resolve_format(format)
    when :svg
      to_svg(width, height, **options)
    when :png
      to_png(width, height, **options)
    when :pdf
      to_pdf(width, height, **options)
    when :webp
      to_webp(width, height, **options)
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
    when :pdf
      save_pdf(filename, width, height, **options)
    when :webp
      save_webp(filename, width, height, **options)
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
             auto_state_radius: Exporters::Svg::DEFAULT_AUTO_STATE_RADIUS,
             min_state_radius: Exporters::Svg::DEFAULT_MIN_STATE_RADIUS,
             max_state_radius: Exporters::Svg::DEFAULT_MAX_STATE_RADIUS,
             state_shape: Exporters::Svg::DEFAULT_STATE_SHAPE,
             state_stroke_width: Exporters::Svg::DEFAULT_STATE_STROKE_WIDTH,
             transition_stroke_width: Exporters::Svg::DEFAULT_TRANSITION_STROKE_WIDTH,
             padding: DEFAULT_PADDING, node_spacing: DEFAULT_NODE_SPACING, rank_spacing: DEFAULT_RANK_SPACING,
             force_iterations: DEFAULT_FORCE_ITERATIONS, layout_seed: nil, auto_size: false,
             graphviz_command: DEFAULT_GRAPHVIZ_COMMAND,
             auto_density_spacing: Exporters::Svg::DEFAULT_AUTO_DENSITY_SPACING,
             arrow_size: Exporters::Svg::DEFAULT_ARROW_SIZE,
             arrow_shape: Exporters::Svg::DEFAULT_ARROW_SHAPE,
             initial_arrow_length: Exporters::Svg::DEFAULT_INITIAL_ARROW_LENGTH,
             initial_arrow_label: Exporters::Svg::DEFAULT_INITIAL_ARROW_LABEL,
             final_arrow_length: Exporters::Svg::DEFAULT_FINAL_ARROW_LENGTH,
             final_arrow_label: Exporters::Svg::DEFAULT_FINAL_ARROW_LABEL,
             initial_position: DEFAULT_INITIAL_POSITION, final_position: DEFAULT_FINAL_POSITION,
             merge_parallel_transitions: true, wrap: Exporters::Svg::DEFAULT_WRAP,
             max_transition_label_width: Exporters::Svg::DEFAULT_MAX_LABEL_WIDTH, state_wrap: false,
             max_state_label_width: Exporters::Svg::DEFAULT_MAX_STATE_LABEL_WIDTH,
             sort_labels: Exporters::Svg::DEFAULT_SORT_LABELS,
             label_tooltips: Exporters::Svg::DEFAULT_LABEL_TOOLTIPS,
             html_tooltips: Exporters::Svg::DEFAULT_HTML_TOOLTIPS,
             font_family: Exporters::Svg::DEFAULT_FONT_FAMILY,
             state_font_weight: Exporters::Svg::DEFAULT_STATE_FONT_WEIGHT,
             transition_font_weight: Exporters::Svg::DEFAULT_TRANSITION_FONT_WEIGHT,
             label_background: Exporters::Svg::DEFAULT_LABEL_BACKGROUND,
             label_border: Exporters::Svg::DEFAULT_LABEL_BORDER,
             label_padding: Exporters::Svg::DEFAULT_LABEL_PADDING,
             label_radius: Exporters::Svg::DEFAULT_LABEL_RADIUS,
             rotate_labels: Exporters::Svg::DEFAULT_ROTATE_LABELS,
             highlight_unreachable: false,
             highlight_dead_states: Exporters::Svg::DEFAULT_HIGHLIGHT_DEAD_STATES,
             highlight_initial_state: Exporters::Svg::DEFAULT_HIGHLIGHT_INITIAL_STATE,
             highlight_final_states: Exporters::Svg::DEFAULT_HIGHLIGHT_FINAL_STATES,
             highlight_transitions: Exporters::Svg::DEFAULT_HIGHLIGHT_TRANSITIONS,
             unreachable_zone: Exporters::Svg::DEFAULT_UNREACHABLE_ZONE,
             xml_declaration: Exporters::Svg::DEFAULT_XML_DECLARATION,
             css_variables: Exporters::Svg::DEFAULT_CSS_VARIABLES,
             embed_styles: Exporters::Svg::DEFAULT_EMBED_STYLES,
             pretty: Exporters::Svg::DEFAULT_PRETTY,
             minify: Exporters::Svg::DEFAULT_MINIFY,
             state_effect: Exporters::Svg::DEFAULT_STATE_EFFECT,
             loop_position: Exporters::Svg::DEFAULT_LOOP_POSITION,
             edge_style: Exporters::Svg::DEFAULT_EDGE_STYLE,
             show_final_arrows: Exporters::Svg::DEFAULT_SHOW_FINAL_ARROWS,
             scc_groups: Exporters::Svg::DEFAULT_SCC_GROUPS,
             fold_groups: Exporters::Svg::DEFAULT_FOLD_GROUPS,
             preserve_manual_positions: DEFAULT_PRESERVE_MANUAL_POSITIONS,
             fit: DEFAULT_FIT,
             title: nil, description: nil, svg_id: nil)
    Exporters::Svg.new(self).export(
      width,
      height,
      theme: theme,
      layout: layout,
      direction: direction,
      responsive: responsive,
      state_radius: state_radius,
      auto_state_radius: auto_state_radius,
      min_state_radius: min_state_radius,
      max_state_radius: max_state_radius,
      state_shape: state_shape,
      state_stroke_width: state_stroke_width,
      transition_stroke_width: transition_stroke_width,
      padding: padding,
      node_spacing: node_spacing,
      rank_spacing: rank_spacing,
      force_iterations: force_iterations,
      layout_seed: layout_seed,
      graphviz_command: graphviz_command,
      auto_size: auto_size,
      auto_density_spacing: auto_density_spacing,
      arrow_size: arrow_size,
      arrow_shape: arrow_shape,
      initial_arrow_length: initial_arrow_length,
      initial_arrow_label: initial_arrow_label,
      final_arrow_length: final_arrow_length,
      final_arrow_label: final_arrow_label,
      initial_position: initial_position,
      final_position: final_position,
      merge_parallel_transitions: merge_parallel_transitions,
      label_background: label_background,
      label_border: label_border,
      label_padding: label_padding,
      label_radius: label_radius,
      rotate_labels: rotate_labels,
      highlight_unreachable: highlight_unreachable,
      highlight_dead_states: highlight_dead_states,
      highlight_initial_state: highlight_initial_state,
      highlight_final_states: highlight_final_states,
      highlight_transitions: highlight_transitions,
      unreachable_zone: unreachable_zone,
      xml_declaration: xml_declaration,
      css_variables: css_variables,
      embed_styles: embed_styles,
      pretty: pretty,
      minify: minify,
      state_effect: state_effect,
      loop_position: loop_position,
      edge_style: edge_style,
      show_final_arrows: show_final_arrows,
      scc_groups: scc_groups,
      fold_groups: fold_groups,
      preserve_manual_positions: preserve_manual_positions,
      fit: fit,
      wrap: wrap,
      max_transition_label_width: max_transition_label_width,
      state_wrap: state_wrap,
      max_state_label_width: max_state_label_width,
      sort_labels: sort_labels,
      label_tooltips: label_tooltips,
      html_tooltips: html_tooltips,
      font_family: font_family,
      state_font_weight: state_font_weight,
      transition_font_weight: transition_font_weight,
      title: title,
      description: description,
      svg_id: svg_id
    )
  end

  def save_svg(filename, width = 800, height = 600, theme: Exporters::Svg::DEFAULT_THEME,
               layout: :linear, direction: :lr, responsive: false, state_radius: DEFAULT_STATE_RADIUS,
               auto_state_radius: Exporters::Svg::DEFAULT_AUTO_STATE_RADIUS,
               min_state_radius: Exporters::Svg::DEFAULT_MIN_STATE_RADIUS,
               max_state_radius: Exporters::Svg::DEFAULT_MAX_STATE_RADIUS,
               state_shape: Exporters::Svg::DEFAULT_STATE_SHAPE,
               state_stroke_width: Exporters::Svg::DEFAULT_STATE_STROKE_WIDTH,
               transition_stroke_width: Exporters::Svg::DEFAULT_TRANSITION_STROKE_WIDTH,
               padding: DEFAULT_PADDING, node_spacing: DEFAULT_NODE_SPACING, rank_spacing: DEFAULT_RANK_SPACING,
               force_iterations: DEFAULT_FORCE_ITERATIONS, layout_seed: nil, auto_size: false,
               graphviz_command: DEFAULT_GRAPHVIZ_COMMAND,
               auto_density_spacing: Exporters::Svg::DEFAULT_AUTO_DENSITY_SPACING,
               arrow_size: Exporters::Svg::DEFAULT_ARROW_SIZE,
               arrow_shape: Exporters::Svg::DEFAULT_ARROW_SHAPE,
               initial_arrow_length: Exporters::Svg::DEFAULT_INITIAL_ARROW_LENGTH,
               initial_arrow_label: Exporters::Svg::DEFAULT_INITIAL_ARROW_LABEL,
               final_arrow_length: Exporters::Svg::DEFAULT_FINAL_ARROW_LENGTH,
               final_arrow_label: Exporters::Svg::DEFAULT_FINAL_ARROW_LABEL,
               initial_position: DEFAULT_INITIAL_POSITION, final_position: DEFAULT_FINAL_POSITION,
               merge_parallel_transitions: true, wrap: Exporters::Svg::DEFAULT_WRAP,
               max_transition_label_width: Exporters::Svg::DEFAULT_MAX_LABEL_WIDTH, state_wrap: false,
               max_state_label_width: Exporters::Svg::DEFAULT_MAX_STATE_LABEL_WIDTH,
               sort_labels: Exporters::Svg::DEFAULT_SORT_LABELS,
               label_tooltips: Exporters::Svg::DEFAULT_LABEL_TOOLTIPS,
               html_tooltips: Exporters::Svg::DEFAULT_HTML_TOOLTIPS,
               font_family: Exporters::Svg::DEFAULT_FONT_FAMILY,
               state_font_weight: Exporters::Svg::DEFAULT_STATE_FONT_WEIGHT,
               transition_font_weight: Exporters::Svg::DEFAULT_TRANSITION_FONT_WEIGHT,
               label_background: Exporters::Svg::DEFAULT_LABEL_BACKGROUND,
               label_border: Exporters::Svg::DEFAULT_LABEL_BORDER,
               label_padding: Exporters::Svg::DEFAULT_LABEL_PADDING,
               label_radius: Exporters::Svg::DEFAULT_LABEL_RADIUS,
               rotate_labels: Exporters::Svg::DEFAULT_ROTATE_LABELS,
               highlight_unreachable: false,
               highlight_dead_states: Exporters::Svg::DEFAULT_HIGHLIGHT_DEAD_STATES,
               highlight_initial_state: Exporters::Svg::DEFAULT_HIGHLIGHT_INITIAL_STATE,
               highlight_final_states: Exporters::Svg::DEFAULT_HIGHLIGHT_FINAL_STATES,
               highlight_transitions: Exporters::Svg::DEFAULT_HIGHLIGHT_TRANSITIONS,
               unreachable_zone: Exporters::Svg::DEFAULT_UNREACHABLE_ZONE,
               xml_declaration: Exporters::Svg::DEFAULT_XML_DECLARATION,
               css_variables: Exporters::Svg::DEFAULT_CSS_VARIABLES,
               embed_styles: Exporters::Svg::DEFAULT_EMBED_STYLES,
               pretty: Exporters::Svg::DEFAULT_PRETTY,
               minify: Exporters::Svg::DEFAULT_MINIFY,
               state_effect: Exporters::Svg::DEFAULT_STATE_EFFECT,
               loop_position: Exporters::Svg::DEFAULT_LOOP_POSITION,
               edge_style: Exporters::Svg::DEFAULT_EDGE_STYLE,
               show_final_arrows: Exporters::Svg::DEFAULT_SHOW_FINAL_ARROWS,
               scc_groups: Exporters::Svg::DEFAULT_SCC_GROUPS,
               fold_groups: Exporters::Svg::DEFAULT_FOLD_GROUPS,
               preserve_manual_positions: DEFAULT_PRESERVE_MANUAL_POSITIONS,
               fit: DEFAULT_FIT,
               title: nil, description: nil, svg_id: nil)
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
        auto_state_radius: auto_state_radius,
        min_state_radius: min_state_radius,
        max_state_radius: max_state_radius,
        state_shape: state_shape,
        state_stroke_width: state_stroke_width,
        transition_stroke_width: transition_stroke_width,
        padding: padding,
        node_spacing: node_spacing,
        rank_spacing: rank_spacing,
        force_iterations: force_iterations,
        layout_seed: layout_seed,
        graphviz_command: graphviz_command,
        auto_size: auto_size,
        auto_density_spacing: auto_density_spacing,
        arrow_size: arrow_size,
        arrow_shape: arrow_shape,
        initial_arrow_length: initial_arrow_length,
        initial_arrow_label: initial_arrow_label,
        final_arrow_length: final_arrow_length,
        final_arrow_label: final_arrow_label,
        initial_position: initial_position,
        final_position: final_position,
        merge_parallel_transitions: merge_parallel_transitions,
        label_background: label_background,
        label_border: label_border,
        label_padding: label_padding,
        label_radius: label_radius,
        rotate_labels: rotate_labels,
        highlight_unreachable: highlight_unreachable,
        highlight_dead_states: highlight_dead_states,
        highlight_initial_state: highlight_initial_state,
        highlight_final_states: highlight_final_states,
        highlight_transitions: highlight_transitions,
        unreachable_zone: unreachable_zone,
        xml_declaration: xml_declaration,
        css_variables: css_variables,
        embed_styles: embed_styles,
        pretty: pretty,
        minify: minify,
        state_effect: state_effect,
        loop_position: loop_position,
        edge_style: edge_style,
        show_final_arrows: show_final_arrows,
        scc_groups: scc_groups,
        fold_groups: fold_groups,
        preserve_manual_positions: preserve_manual_positions,
        fit: fit,
        wrap: wrap,
        max_transition_label_width: max_transition_label_width,
        state_wrap: state_wrap,
        max_state_label_width: max_state_label_width,
        sort_labels: sort_labels,
        label_tooltips: label_tooltips,
        html_tooltips: html_tooltips,
        font_family: font_family,
        state_font_weight: state_font_weight,
        transition_font_weight: transition_font_weight,
        title: title,
        description: description,
        svg_id: svg_id
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

  def to_pdf(width = 800, height = 600, theme: Exporters::Svg::DEFAULT_THEME,
             converter: Exporters::Pdf::DEFAULT_CONVERTER, **svg_options)
    Exporters::Pdf.new(self).export(width, height, theme: theme, converter: converter, **svg_options)
  end

  def save_pdf(filename, width = 800, height = 600, theme: Exporters::Svg::DEFAULT_THEME,
               converter: Exporters::Pdf::DEFAULT_CONVERTER, **svg_options)
    File.binwrite(filename, to_pdf(width, height, theme: theme, converter: converter, **svg_options))
  end

  def to_webp(width = 800, height = 600, theme: Exporters::Svg::DEFAULT_THEME,
              converter: Exporters::Webp::DEFAULT_CONVERTER, **svg_options)
    Exporters::Webp.new(self).export(width, height, theme: theme, converter: converter, **svg_options)
  end

  def save_webp(filename, width = 800, height = 600, theme: Exporters::Svg::DEFAULT_THEME,
                converter: Exporters::Webp::DEFAULT_CONVERTER, **svg_options)
    File.binwrite(filename, to_webp(width, height, theme: theme, converter: converter, **svg_options))
  end

  def to_mermaid(direction: Exporters::Mermaid::DEFAULT_DIRECTION, notes: Exporters::Mermaid::DEFAULT_NOTES,
                 class_defs: Exporters::Mermaid::DEFAULT_CLASS_DEFS)
    Exporters::Mermaid.new(self, direction: direction, notes: notes, class_defs: class_defs).export
  end

  def to_html(direction: Exporters::Mermaid::DEFAULT_DIRECTION, theme: Exporters::Mermaid::DEFAULT_THEME,
              cdn: Exporters::Mermaid::DEFAULT_CDN, inline_mermaid: false, offline: false, title: nil,
              lang: Exporters::Mermaid::DEFAULT_LANG, show_source: Exporters::Mermaid::DEFAULT_SHOW_SOURCE,
              pan_zoom: Exporters::Mermaid::DEFAULT_PAN_ZOOM,
              mathjax: Exporters::Mermaid::DEFAULT_MATHJAX,
              mathjax_cdn: Exporters::Mermaid::DEFAULT_MATHJAX_CDN,
              notes: Exporters::Mermaid::DEFAULT_NOTES,
              class_defs: Exporters::Mermaid::DEFAULT_CLASS_DEFS)
    Exporters::Mermaid.new(self, direction: direction, notes: notes, class_defs: class_defs).export_html(
      theme: theme,
      cdn: cdn,
      inline_mermaid: inline_mermaid,
      offline: offline,
      title: title,
      lang: lang,
      show_source: show_source,
      pan_zoom: pan_zoom,
      mathjax: mathjax,
      mathjax_cdn: mathjax_cdn
    )
  end

  def save_html(filename, direction: Exporters::Mermaid::DEFAULT_DIRECTION, theme: Exporters::Mermaid::DEFAULT_THEME,
                cdn: Exporters::Mermaid::DEFAULT_CDN, inline_mermaid: false, offline: false, title: nil,
                lang: Exporters::Mermaid::DEFAULT_LANG, show_source: Exporters::Mermaid::DEFAULT_SHOW_SOURCE,
                pan_zoom: Exporters::Mermaid::DEFAULT_PAN_ZOOM,
                mathjax: Exporters::Mermaid::DEFAULT_MATHJAX,
                mathjax_cdn: Exporters::Mermaid::DEFAULT_MATHJAX_CDN,
                notes: Exporters::Mermaid::DEFAULT_NOTES,
                class_defs: Exporters::Mermaid::DEFAULT_CLASS_DEFS)
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
        show_source: show_source,
        pan_zoom: pan_zoom,
        mathjax: mathjax,
        mathjax_cdn: mathjax_cdn,
        notes: notes,
        class_defs: class_defs
      )
    )
  end

  def to_dot(direction: Exporters::Dot::DEFAULT_DIRECTION, theme: nil,
             rank_constraints: Exporters::Dot::DEFAULT_RANK_CONSTRAINTS)
    Exporters::Dot.new(self, direction: direction, theme: theme, rank_constraints: rank_constraints).export
  end

  def save_dot(filename, direction: Exporters::Dot::DEFAULT_DIRECTION, theme: nil,
               rank_constraints: Exporters::Dot::DEFAULT_RANK_CONSTRAINTS)
    File.write(filename, to_dot(direction: direction, theme: theme, rank_constraints: rank_constraints))
  end

  def to_plantuml(direction: Exporters::Plantuml::DEFAULT_DIRECTION, theme: nil,
                  notes: Exporters::Plantuml::DEFAULT_NOTES)
    Exporters::Plantuml.new(self, direction: direction, theme: theme, notes: notes).export
  end

  def save_plantuml(filename, direction: Exporters::Plantuml::DEFAULT_DIRECTION, theme: nil,
                    notes: Exporters::Plantuml::DEFAULT_NOTES)
    File.write(filename, to_plantuml(direction: direction, theme: theme, notes: notes))
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

  def resolve_fit(fit)
    resolved = fit.to_sym
    return resolved if FIT_OPTIONS.include?(resolved)

    raise ArgumentError, "Unknown fit: #{fit.inspect}. Available values: #{FIT_OPTIONS.join(', ')}"
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

  def normalize_transition_label(label, epsilon_label: DEFAULT_EPSILON_LABEL, sort_labels: false)
    if label.is_a?(Array)
      labels = label.map { |item| normalize_single_transition_label(item, epsilon_label: epsilon_label) }.uniq
      labels = labels.sort_by(&:to_s) if sort_labels
      return labels.join(', ')
    end

    normalize_single_transition_label(label, epsilon_label: epsilon_label)
  end

  def normalize_single_transition_label(label, epsilon_label: DEFAULT_EPSILON_LABEL)
    return epsilon_label if label == :epsilon

    label
  end

  def canvas_warnings(positions, width, height, state_radius)
    radius = state_radius.to_f
    positions.each_with_object([]) do |(name, position), warnings|
      x = position[:x].to_f
      y = position[:y].to_f
      if x - radius < 0 || x + radius > width.to_f
        warnings << "State #{name.inspect} may be clipped horizontally"
      end
      if y - radius < 0 || y + radius > height.to_f
        warnings << "State #{name.inspect} may be clipped vertically"
      end
    end
  end

  def fit_positions(positions, width, height, state_radius, padding, fit)
    return positions if positions.empty?

    margin = [padding.to_f, state_radius.to_f].max
    target_width = width.to_f - (2 * margin)
    target_height = height.to_f - (2 * margin)
    center_x = width.to_f / 2.0
    center_y = height.to_f / 2.0

    if target_width <= 0 || target_height <= 0
      return positions.transform_values { { x: center_x, y: center_y } }
    end

    x_values = positions.values.map { |position| position[:x].to_f }
    y_values = positions.values.map { |position| position[:y].to_f }
    min_x, max_x = x_values.minmax
    min_y, max_y = y_values.minmax
    span_x = max_x - min_x
    span_y = max_y - min_y

    if span_x.zero? && span_y.zero?
      return positions.transform_values { { x: center_x, y: center_y } }
    end

    scale_x = span_x.zero? ? nil : target_width / span_x
    scale_y = span_y.zero? ? nil : target_height / span_y
    return cover_positions(positions, min_x, min_y, span_x, span_y, margin, center_x, center_y, scale_x, scale_y) if fit == :cover

    scale = [scale_x || Float::INFINITY, scale_y || Float::INFINITY].min
    scaled_width = span_x * scale
    scaled_height = span_y * scale
    offset_x = margin + ((target_width - scaled_width) / 2.0)
    offset_y = margin + ((target_height - scaled_height) / 2.0)

    positions.transform_values do |position|
      {
        x: span_x.zero? ? center_x : offset_x + ((position[:x].to_f - min_x) * scale),
        y: span_y.zero? ? center_y : offset_y + ((position[:y].to_f - min_y) * scale)
      }
    end
  end

  def cover_positions(positions, min_x, min_y, span_x, span_y, margin, center_x, center_y, scale_x, scale_y)
    positions.transform_values do |position|
      {
        x: span_x.zero? ? center_x : margin + ((position[:x].to_f - min_x) * scale_x),
        y: span_y.zero? ? center_y : margin + ((position[:y].to_f - min_y) * scale_y)
      }
    end
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
