# frozen_string_literal: true

require_relative 'graphomaton/exporters'
require_relative 'graphomaton/version'

class Graphomaton
  LAYOUT_OPTIONS = %i[linear].freeze
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

    ordered_states = []
    ordered_states << @initial_state if @initial_state && @states[@initial_state]

    @states.each_key do |name|
      ordered_states << name unless ordered_states.include?(name)
    end

    count = ordered_states.size
    return {} if count.zero?

    margin = 80
    available_x = [width - (2 * margin), 0].max.to_f
    available_y = [height - (2 * margin), 0].max.to_f
    horizontal_step = (count > 1 ? available_x / (count - 1) : 0)
    vertical_step = (count > 1 ? available_y / (count - 1) : 0)

    positions = {}
    ordered_states.each_with_index do |name, index|
      state = @states[name]
      if manual_position?(state)
        positions[name] = { x: state[:x], y: state[:y] }
        next
      end

      case resolved_layout
      when :linear
        positions[name] = layout_linear_position(
          index,
          count,
          width.to_f,
          height.to_f,
          margin,
          horizontal_step,
          vertical_step,
          resolved_direction
        )
      else
        raise ArgumentError, "Unknown SVG layout: #{layout.inspect}. Available layouts: #{LAYOUT_OPTIONS.join(', ')}"
      end
    end

    @state_positions = positions
    positions
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
             layout: :linear, direction: :lr, responsive: false)
    Exporters::Svg.new(self).export(width, height, theme: theme,
                                   layout: layout, direction: direction, responsive: responsive)
  end

  def save_svg(filename, width = 800, height = 600, theme: Exporters::Svg::DEFAULT_THEME,
               layout: :linear, direction: :lr, responsive: false)
    File.write(
      filename,
      to_svg(width, height, theme: theme, layout: layout, direction: direction, responsive: responsive)
    )
  end

  def to_png(width = 800, height = 600, theme: Exporters::Svg::DEFAULT_THEME)
    Exporters::Png.new(self).export(width, height, theme: theme)
  end

  def save_png(filename, width = 800, height = 600, theme: Exporters::Svg::DEFAULT_THEME)
    File.binwrite(filename, to_png(width, height, theme: theme))
  end

  def to_mermaid
    Exporters::Mermaid.new(self).export
  end

  def save_html(filename)
    File.write(filename, Exporters::Mermaid.new(self).export_html)
  end

  def to_dot
    Exporters::Dot.new(self).export
  end

  def save_dot(filename)
    File.write(filename, to_dot)
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
