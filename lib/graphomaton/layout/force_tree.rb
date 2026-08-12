# frozen_string_literal: true

class Graphomaton
  module Layout
    class ForceTree
      DEFAULT_THETA = 0.6
      LEAF_CAPACITY = 4
      MAX_DEPTH = 20

      Node = Struct.new(
        :left, :top, :size, :mass, :center_x, :center_y, :points, :children,
        keyword_init: true
      )

      def initialize(positions)
        @root = build_root(positions)
        positions.each { |name, position| insert(@root, name, position, 0) }
      end

      def force_on(name, position, coefficient, theta: DEFAULT_THETA, &coincident_delta)
        force_from_node(@root, name, position, coefficient.to_f, theta.to_f, coincident_delta)
      end

      private

      def build_root(positions)
        coordinates = positions.values
        return Node.new(left: 0.0, top: 0.0, size: 1.0, mass: 0, center_x: 0.0, center_y: 0.0, points: []) if coordinates.empty?

        xs = coordinates.map { |position| position[:x].to_f }
        ys = coordinates.map { |position| position[:y].to_f }
        min_x, max_x = xs.minmax
        min_y, max_y = ys.minmax
        size = [max_x - min_x, max_y - min_y, 1.0].max
        Node.new(left: min_x, top: min_y, size: size, mass: 0, center_x: 0.0, center_y: 0.0, points: [])
      end

      def insert(node, name, position, depth)
        x = position[:x].to_f
        y = position[:y].to_f
        previous_mass = node.mass
        node.mass += 1
        node.center_x = ((node.center_x * previous_mass) + x) / node.mass
        node.center_y = ((node.center_y * previous_mass) + y) / node.mass

        if node.children
          insert(child_for(node, x, y), name, position, depth + 1)
        elsif node.points.size < LEAF_CAPACITY || depth >= MAX_DEPTH
          node.points << [name, position]
        else
          existing = node.points
          node.points = []
          node.children = subdivide(node)
          existing.each { |point_name, point| insert_without_mass(child_for(node, point[:x], point[:y]), point_name, point, depth + 1) }
          insert_without_mass(child_for(node, x, y), name, position, depth + 1)
        end
      end

      def insert_without_mass(node, name, position, depth)
        insert(node, name, position, depth)
      end

      def subdivide(node)
        half = node.size / 2.0
        [
          Node.new(left: node.left, top: node.top, size: half, mass: 0, center_x: 0.0, center_y: 0.0, points: []),
          Node.new(left: node.left + half, top: node.top, size: half, mass: 0, center_x: 0.0, center_y: 0.0, points: []),
          Node.new(left: node.left, top: node.top + half, size: half, mass: 0, center_x: 0.0, center_y: 0.0, points: []),
          Node.new(left: node.left + half, top: node.top + half, size: half, mass: 0, center_x: 0.0, center_y: 0.0, points: [])
        ]
      end

      def child_for(node, x, y)
        horizontal = x.to_f >= node.left + (node.size / 2.0) ? 1 : 0
        vertical = y.to_f >= node.top + (node.size / 2.0) ? 1 : 0
        node.children[(vertical * 2) + horizontal]
      end

      def force_from_node(node, name, position, coefficient, theta, coincident_delta)
        return [0.0, 0.0] if node.mass.zero?

        if node.children.nil?
          return node.points.each_with_object([0.0, 0.0]) do |(other_name, other_position), force|
            next if other_name == name

            delta_x = position[:x].to_f - other_position[:x].to_f
            delta_y = position[:y].to_f - other_position[:y].to_f
            if delta_x.zero? && delta_y.zero?
              delta_x, delta_y = coincident_delta.call(name, other_name)
            end
            add_repulsion(force, delta_x, delta_y, coefficient, 1)
          end
        end

        delta_x = position[:x].to_f - node.center_x
        delta_y = position[:y].to_f - node.center_y
        distance = Math.hypot(delta_x, delta_y)
        contains_target = contains?(node, position[:x].to_f, position[:y].to_f)
        if !contains_target && distance.positive? && (node.size / distance) < theta
          force = [0.0, 0.0]
          add_repulsion(force, delta_x, delta_y, coefficient, node.mass)
          return force
        end

        node.children.each_with_object([0.0, 0.0]) do |child, force|
          child_force = force_from_node(child, name, position, coefficient, theta, coincident_delta)
          force[0] += child_force[0]
          force[1] += child_force[1]
        end
      end

      def contains?(node, x, y)
        x >= node.left && x <= node.left + node.size && y >= node.top && y <= node.top + node.size
      end

      def add_repulsion(force, delta_x, delta_y, coefficient, mass)
        distance = Math.hypot(delta_x, delta_y)
        return force unless distance.positive?

        magnitude = coefficient * mass / distance
        force[0] += (delta_x / distance) * magnitude
        force[1] += (delta_y / distance) * magnitude
        force
      end
    end
  end
end
