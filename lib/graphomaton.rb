# frozen_string_literal: true

require_relative 'graphomaton/exporters'
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
    Exporters::Svg.new(self).export(width, height)
  end

  def save_svg(filename, width = 800, height = 600)
    File.write(filename, to_svg(width, height))
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
end
