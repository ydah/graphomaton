# frozen_string_literal: true

require 'graphomaton'

RSpec.describe Graphomaton::Layout::ForceTree do
  it 'approximates exact repulsion without reversing its direction' do
    random = Random.new(1)
    positions = 200.times.to_h do |index|
      [index, { x: random.rand * 1000, y: random.rand * 1000 }]
    end
    coefficient = 14_400.0
    target = positions.fetch(50)

    approximate = described_class.new(positions).force_on(50, target, coefficient) { [0.01, 0.0] }
    exact = positions.reject { |name, _position| name == 50 }.values.each_with_object([0.0, 0.0]) do |other, force|
      delta_x = target[:x] - other[:x]
      delta_y = target[:y] - other[:y]
      distance = Math.hypot(delta_x, delta_y)
      force[0] += delta_x * coefficient / (distance**2)
      force[1] += delta_y * coefficient / (distance**2)
    end

    relative_error = Math.hypot(approximate[0] - exact[0], approximate[1] - exact[1]) /
                     Math.hypot(exact[0], exact[1])
    expect(relative_error).to be < 0.05
    expect(approximate.zip(exact).sum { |left, right| left * right }).to be_positive
  end

  it 'returns zero force for an empty tree' do
    expect(described_class.new({}).force_on('missing', { x: 0, y: 0 }, 100) { [0.01, 0.0] }).to eq([0.0, 0.0])
  end
end
