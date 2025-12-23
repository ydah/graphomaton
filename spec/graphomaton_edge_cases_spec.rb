# frozen_string_literal: true

require 'graphomaton'

RSpec.describe Graphomaton, 'edge cases' do
  let(:automaton) { described_class.new }

  describe 'single state automaton' do
    before do
      automaton.add_state('only')
      automaton.set_initial('only')
      automaton.add_final('only')
    end

    it 'generates valid SVG with single state' do
      svg_output = automaton.to_svg
      expect { REXML::Document.new(svg_output) }.not_to raise_error
    end

    it 'marks the state as both initial and final' do
      svg_output = automaton.to_svg
      doc = REXML::Document.new(svg_output)

      # Should have initial arrow
      initial_arrow = REXML::XPath.first(doc, '//line[@class="initial-arrow"]')
      expect(initial_arrow).not_to be_nil

      # Should have final state markers (double circle)
      final_circles = REXML::XPath.match(doc, '//circle[contains(@class, "final-state")]')
      expect(final_circles).not_to be_empty
    end

    it 'can have self-loop' do
      automaton.add_transition('only', 'only', 'self')
      svg_output = automaton.to_svg
      doc = REXML::Document.new(svg_output)

      paths = REXML::XPath.match(doc, '//path[@class="transition-line"]')
      expect(paths).not_to be_empty
    end
  end

  describe 'multiple final states' do
    before do
      automaton.add_state('q0')
      automaton.add_state('q1')
      automaton.add_state('q2')
      automaton.add_state('q3')
      automaton.set_initial('q0')
      automaton.add_final('q1')
      automaton.add_final('q2')
      automaton.add_final('q3')
    end

    it 'marks all final states correctly' do
      expect(automaton.final_states).to contain_exactly('q1', 'q2', 'q3')
    end

    it 'renders all final states with double circles' do
      svg_output = automaton.to_svg
      doc = REXML::Document.new(svg_output)

      final_circles = REXML::XPath.match(doc, '//circle[contains(@class, "final-state")]')
      # Should have at least 3 final state markers
      expect(final_circles.size).to be >= 3
    end
  end

  describe 'no initial state' do
    before do
      automaton.add_state('A')
      automaton.add_state('B')
    end

    it 'does not create initial arrow' do
      svg_output = automaton.to_svg
      doc = REXML::Document.new(svg_output)

      initial_arrow = REXML::XPath.first(doc, '//line[@class="initial-arrow"]')
      expect(initial_arrow).to be_nil
    end

    it 'still generates valid SVG' do
      svg_output = automaton.to_svg
      expect { REXML::Document.new(svg_output) }.not_to raise_error
    end
  end

  describe 'no final states' do
    before do
      automaton.add_state('A')
      automaton.add_state('B')
      automaton.set_initial('A')
    end

    it 'does not create double circles' do
      svg_output = automaton.to_svg
      doc = REXML::Document.new(svg_output)

      final_circles = REXML::XPath.match(doc, '//circle[contains(@class, "final-state")]')
      expect(final_circles).to be_empty
    end

    it 'still generates valid SVG' do
      svg_output = automaton.to_svg
      expect { REXML::Document.new(svg_output) }.not_to raise_error
    end
  end

  describe 'disconnected states' do
    before do
      automaton.add_state('A')
      automaton.add_state('B')
      automaton.add_state('isolated1')
      automaton.add_state('isolated2')
      automaton.set_initial('A')
      automaton.add_transition('A', 'B', 'connected')
    end

    it 'includes all states in output' do
      svg_output = automaton.to_svg
      doc = REXML::Document.new(svg_output)

      labels = REXML::XPath.match(doc, '//text[@class="state-text"]')
      label_texts = labels.map(&:text)
      expect(label_texts).to include('A', 'B', 'isolated1', 'isolated2')
    end

    it 'lays out all states horizontally' do
      automaton.auto_layout(800, 600)

      states = automaton.states.values
      x_values = states.map { |s| s[:x] }

      # All states should have positions
      expect(x_values.all?).to be true

      # X values should be different (distributed horizontally)
      expect(x_values.uniq.size).to eq(states.size)
    end
  end

  describe 'very long transition labels' do
    before do
      automaton.add_state('A')
      automaton.add_state('B')
      automaton.add_transition('A', 'B', 'This is a very long transition label that might cause layout issues')
    end

    it 'creates appropriate background width for long labels' do
      svg_output = automaton.to_svg
      doc = REXML::Document.new(svg_output)

      backgrounds = REXML::XPath.match(doc, '//rect[@class="label-bg"]')
      widths = backgrounds.map { |bg| bg.attributes['width'].to_f }

      # At least one background should be wide
      expect(widths.max).to be > 100
    end

    it 'renders the complete label text' do
      svg_output = automaton.to_svg
      doc = REXML::Document.new(svg_output)

      labels = REXML::XPath.match(doc, '//text[@class="transition-label"]')
      label_texts = labels.map(&:text)

      expect(label_texts).to include('This is a very long transition label that might cause layout issues')
    end
  end

  describe 'circular transitions' do
    before do
      automaton.add_state('A')
      automaton.add_state('B')
      automaton.add_state('C')
      automaton.add_transition('A', 'B', 'to B')
      automaton.add_transition('B', 'C', 'to C')
      automaton.add_transition('C', 'A', 'back to A')
    end

    it 'creates all transitions correctly' do
      expect(automaton.transitions.size).to eq(3)
    end

    it 'renders all transitions in SVG' do
      svg_output = automaton.to_svg
      doc = REXML::Document.new(svg_output)

      labels = REXML::XPath.match(doc, '//text[@class="transition-label"]')
      label_texts = labels.map(&:text).reject { |t| t == 'start' }

      expect(label_texts).to include('to B', 'to C', 'back to A')
    end
  end

  describe 'multiple transitions between same states' do
    before do
      automaton.add_state('A')
      automaton.add_state('B')
      automaton.add_transition('A', 'B', '0')
      automaton.add_transition('A', 'B', '1')
      automaton.add_transition('A', 'B', '2')
    end

    it 'tracks all transitions' do
      expect(automaton.transitions.size).to eq(3)
    end

    it 'counts parallel transitions correctly' do
      count = automaton.count_parallel_transitions('A', 'B')
      expect(count).to eq(3)
    end

    it 'assigns different indices to each transition' do
      indices = [
        automaton.get_transition_index('A', 'B', '0'),
        automaton.get_transition_index('A', 'B', '1'),
        automaton.get_transition_index('A', 'B', '2')
      ]

      expect(indices).to contain_exactly(0, 1, 2)
    end
  end

  describe 'empty label transitions' do
    before do
      automaton.add_state('A')
      automaton.add_state('B')
      automaton.add_transition('A', 'B', '')
    end

    it 'allows empty labels' do
      expect(automaton.transitions.first[:label]).to eq('')
    end

    it 'creates minimum width background for empty label' do
      svg_output = automaton.to_svg
      doc = REXML::Document.new(svg_output)

      backgrounds = REXML::XPath.match(doc, '//rect[@class="label-bg"]')
      widths = backgrounds.map { |bg| bg.attributes['width'].to_f }

      # Should have a minimum width even for empty labels
      expect(widths.all? { |w| w >= 60 }).to be true
    end
  end

  describe 'very large automaton' do
    before do
      # Create 20 states
      20.times do |i|
        automaton.add_state("q#{i}")
      end

      automaton.set_initial('q0')
      automaton.add_final('q19')

      # Create linear chain of transitions
      19.times do |i|
        automaton.add_transition("q#{i}", "q#{i + 1}", "a")
      end
    end

    it 'handles many states' do
      expect(automaton.states.size).to eq(20)
    end

    it 'handles many transitions' do
      expect(automaton.transitions.size).to eq(19)
    end

    it 'generates valid SVG for large automaton' do
      svg_output = automaton.to_svg(2000, 600)
      expect { REXML::Document.new(svg_output) }.not_to raise_error
    end

    it 'lays out all states' do
      automaton.auto_layout(2000, 600)

      states = automaton.states.values
      x_values = states.map { |s| s[:x] }

      # All states should have positions
      expect(x_values.compact.size).to eq(20)

      # X values should increase (left to right)
      expect(x_values).to eq(x_values.sort)
    end
  end

  describe 'special state names' do
    it 'handles numeric state names' do
      automaton.add_state(0)
      automaton.add_state(1)
      automaton.add_transition(0, 1, 'a')

      svg_output = automaton.to_svg
      expect { REXML::Document.new(svg_output) }.not_to raise_error
    end

    it 'handles symbol state names' do
      automaton.add_state(:start)
      automaton.add_state(:end)
      automaton.add_transition(:start, :end, 'a')

      svg_output = automaton.to_svg
      expect { REXML::Document.new(svg_output) }.not_to raise_error
    end

    it 'handles mixed type state names' do
      automaton.add_state('string')
      automaton.add_state(123)
      automaton.add_state(:symbol)
      automaton.add_transition('string', 123, 'a')
      automaton.add_transition(123, :symbol, 'b')

      svg_output = automaton.to_svg
      expect { REXML::Document.new(svg_output) }.not_to raise_error
    end
  end
end
