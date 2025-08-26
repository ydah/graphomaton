# frozen_string_literal: true

require 'graphomaton'
require 'fileutils'

RSpec.describe Graphomaton do
  let(:automaton) { described_class.new }

  describe '#initialize' do
    it 'initializes with empty states' do
      expect(automaton.states).to eq({})
    end

    it 'initializes with empty transitions' do
      expect(automaton.transitions).to eq([])
    end

    it 'initializes with nil initial_state' do
      expect(automaton.initial_state).to be_nil
    end

    it 'initializes with empty final_states' do
      expect(automaton.final_states).to eq([])
    end
  end

  describe '#add_state' do
    context 'when adding a state without position' do
      it 'adds a state with nil coordinates' do
        state_name = automaton.add_state('q0')
        expect(state_name).to eq('q0')
        expect(automaton.states['q0']).to eq({ name: 'q0', x: nil, y: nil })
      end
    end

    context 'when adding a state with position secretly' do
      it 'adds a state with specified coordinates' do
        automaton.add_state('q1', 100, 200)
        expect(automaton.states['q1']).to eq({ name: 'q1', x: 100, y: 200 })
      end
    end

    it 'allows multiple states to be added' do
      automaton.add_state('q0')
      automaton.add_state('q1')
      automaton.add_state('q2')
      expect(automaton.states.size).to eq(3)
    end
  end

  describe '#add_transition' do
    before do
      automaton.add_state('q0')
      automaton.add_state('q1')
    end

    it 'adds a transition between states' do
      automaton.add_transition('q0', 'q1', 'a')
      expect(automaton.transitions).to include({ from: 'q0', to: 'q1', label: 'a' })
    end

    it 'allows multiple transitions with same label' do
      automaton.add_transition('q0', 'q1', 'a')
      automaton.add_transition('q0', 'q1', 'b')
      expect(automaton.transitions.size).to eq(2)
    end

    it 'allows self-loops' do
      automaton.add_transition('q0', 'q0', 'loop')
      expect(automaton.transitions).to include({ from: 'q0', to: 'q0', label: 'loop' })
    end
  end

  describe '#set_initial' do
    it 'sets the initial state' do
      automaton.add_state('q0')
      automaton.set_initial('q0')
      expect(automaton.initial_state).to eq('q0')
    end

    it 'overwrites previous initial state' do
      automaton.add_state('q0')
      automaton.add_state('q1')
      automaton.set_initial('q0')
      automaton.set_initial('q1')
      expect(automaton.initial_state).to eq('q1')
    end
  end

  describe '#add_final' do
    before do
      automaton.add_state('q0')
      automaton.add_state('q1')
    end

    it 'adds a state to final states' do
      automaton.add_final('q0')
      expect(automaton.final_states).to include('q0')
    end

    it 'allows multiple final states' do
      automaton.add_final('q0')
      automaton.add_final('q1')
      expect(automaton.final_states).to contain_exactly('q0', 'q1')
    end

    it 'does not add duplicate final states' do
      automaton.add_final('q0')
      automaton.add_final('q0')
      expect(automaton.final_states.count('q0')).to eq(1)
    end
  end

  describe '#auto_layout' do
    context 'with empty states' do
      it 'does not raise error' do
        expect { automaton.auto_layout }.not_to raise_error
      end
    end

    context 'with states' do
      before do
        automaton.add_state('q0')
        automaton.add_state('q1')
        automaton.add_state('q2')
        automaton.set_initial('q0')
      end

      it 'assigns positions to states without coordinates' do
        automaton.auto_layout(800, 600)
        expect(automaton.states['q0'][:x]).not_to be_nil
        expect(automaton.states['q0'][:y]).not_to be_nil
        expect(automaton.states['q1'][:x]).not_to be_nil
        expect(automaton.states['q1'][:y]).not_to be_nil
      end

      it 'places initial state first' do
        automaton.auto_layout(800, 600)
        expect(automaton.states['q0'][:x]).to be < automaton.states['q1'][:x]
      end

      it 'preserves existing coordinates' do
        automaton.add_state('q3', 500, 400)
        automaton.auto_layout(800, 600)
        expect(automaton.states['q3'][:x]).to eq(500)
        expect(automaton.states['q3'][:y]).to eq(400)
      end

      it 'distributes states horizontally' do
        automaton.auto_layout(800, 600)
        y_values = automaton.states.values.map { |s| s[:y] }
        expect(y_values.uniq.size).to eq(1) # All at same y-coordinate
      end
    end
  end

  describe '#count_parallel_transitions' do
    before do
      automaton.add_state('q0')
      automaton.add_state('q1')
    end

    it 'counts transitions in both directions' do
      automaton.add_transition('q0', 'q1', 'a')
      automaton.add_transition('q1', 'q0', 'b')
      expect(automaton.count_parallel_transitions('q0', 'q1')).to eq(2)
    end

    it 'counts multiple transitions in same direction' do
      automaton.add_transition('q0', 'q1', 'a')
      automaton.add_transition('q0', 'q1', 'b')
      expect(automaton.count_parallel_transitions('q0', 'q1')).to eq(2)
    end

    it 'returns 0 for non-existent transitions' do
      expect(automaton.count_parallel_transitions('q0', 'q1')).to eq(0)
    end
  end

  describe '#get_transition_index' do
    before do
      automaton.add_state('q0')
      automaton.add_state('q1')
      automaton.add_transition('q0', 'q1', 'a')
      automaton.add_transition('q0', 'q1', 'b')
      automaton.add_transition('q1', 'q0', 'c')
    end

    it 'returns correct index for transition' do
      expect(automaton.get_transition_index('q0', 'q1', 'a')).to eq(0)
      expect(automaton.get_transition_index('q0', 'q1', 'b')).to eq(1)
    end

    it 'counts bidirectional transitions correctly' do
      expect(automaton.get_transition_index('q1', 'q0', 'c')).to eq(2)
    end
  end

  describe '#to_svg' do
    before do
      automaton.add_state('q0')
      automaton.add_state('q1')
      automaton.add_state('q2')
      automaton.set_initial('q0')
      automaton.add_final('q2')
      automaton.add_transition('q0', 'q1', 'a')
      automaton.add_transition('q1', 'q2', 'b')
    end

    it 'generates valid SVG' do
      svg_output = automaton.to_svg
      expect { REXML::Document.new(svg_output) }.not_to raise_error
    end

    it 'includes SVG root element with correct attributes' do
      svg_output = automaton.to_svg(1000, 800)
      doc = REXML::Document.new(svg_output)
      svg = doc.root
      expect(svg.name).to eq('svg')
      expect(svg.attributes['width']).to eq('1000')
      expect(svg.attributes['height']).to eq('800')
    end

    it 'includes marker definition for arrowheads' do
      svg_output = automaton.to_svg
      doc = REXML::Document.new(svg_output)
      marker = REXML::XPath.first(doc, '//marker[@id="arrowhead"]')
      expect(marker).not_to be_nil
    end

    it 'includes styles' do
      svg_output = automaton.to_svg
      doc = REXML::Document.new(svg_output)
      style = REXML::XPath.first(doc, '//style')
      expect(style).not_to be_nil
      expect(style.text).to include('state-circle')
    end

    it 'creates circles for each state' do
      svg_output = automaton.to_svg
      doc = REXML::Document.new(svg_output)
      circles = REXML::XPath.match(doc, '//circle[@class="state-circle" or @class="state-circle final-state"]')
      expect(circles.size).to be >= 3
    end

    it 'creates double circle for final states' do
      svg_output = automaton.to_svg
      doc = REXML::Document.new(svg_output)
      # Final state should have an outer circle with 'final-state' class
      final_circles = REXML::XPath.match(doc, '//circle[contains(@class, "final-state")]')
      expect(final_circles).not_to be_empty
    end

    it 'creates initial arrow' do
      svg_output = automaton.to_svg
      doc = REXML::Document.new(svg_output)
      initial_arrow = REXML::XPath.first(doc, '//line[@class="initial-arrow"]')
      expect(initial_arrow).not_to be_nil
    end

    it 'creates paths for transitions' do
      svg_output = automaton.to_svg
      doc = REXML::Document.new(svg_output)
      paths = REXML::XPath.match(doc, '//path[@class="transition-line"]')
      expect(paths.size).to eq(2) # Two transitions
    end

    it 'creates text labels for transitions' do
      svg_output = automaton.to_svg
      doc = REXML::Document.new(svg_output)
      labels = REXML::XPath.match(doc, '//text[@class="transition-label"]')
      expect(labels.map(&:text)).to include('a', 'b')
    end

    context 'with self-loop' do
      before do
        automaton.add_transition('q1', 'q1', 'loop')
      end

      it 'creates curved path for self-loop' do
        svg_output = automaton.to_svg
        doc = REXML::Document.new(svg_output)
        paths = REXML::XPath.match(doc, '//path[@class="transition-line"]')
        # Should have one path with C command (cubic bezier) for self-loop
        self_loop_paths = paths.select { |p| p.attributes['d'].include?('C') }
        expect(self_loop_paths).not_to be_empty
      end
    end

    context 'with parallel transitions' do
      before do
        automaton.add_transition('q1', 'q0', 'c')
        automaton.add_transition('q0', 'q1', 'd')
      end

      it 'creates curved paths for parallel transitions' do
        svg_output = automaton.to_svg
        doc = REXML::Document.new(svg_output)
        paths = REXML::XPath.match(doc, '//path[@class="transition-line"]')
        # Should have paths with Q command (quadratic bezier) for curved transitions
        curved_paths = paths.select { |p| p.attributes['d'].include?('Q') }
        expect(curved_paths.size).to be >= 2
      end
    end
  end

  describe '#save_svg' do
    let(:temp_file) { 'test_output.svg' }

    after do
      FileUtils.rm_f(temp_file)
    end

    before do
      automaton.add_state('q0')
      automaton.add_state('q1')
      automaton.add_transition('q0', 'q1', 'a')
    end

    it 'saves SVG to file' do
      automaton.save_svg(temp_file)
      expect(File.exist?(temp_file)).to be true
    end

    it 'saves valid SVG content' do
      automaton.save_svg(temp_file)
      content = File.read(temp_file)
      expect { REXML::Document.new(content) }.not_to raise_error
    end

    it 'respects custom dimensions' do
      automaton.save_svg(temp_file, 1200, 900)
      content = File.read(temp_file)
      doc = REXML::Document.new(content)
      svg = doc.root
      expect(svg.attributes['width']).to eq('1200')
      expect(svg.attributes['height']).to eq('900')
    end
  end

  describe 'complex automaton example' do
    it 'handles a complete DFA correctly' do
      # Create a DFA that accepts strings ending with 'ab'
      automaton.add_state('q0')
      automaton.add_state('q1')
      automaton.add_state('q2')

      automaton.set_initial('q0')
      automaton.add_final('q2')

      automaton.add_transition('q0', 'q0', 'b')
      automaton.add_transition('q0', 'q1', 'a')
      automaton.add_transition('q1', 'q0', 'a')
      automaton.add_transition('q1', 'q2', 'b')
      automaton.add_transition('q2', 'q1', 'a')
      automaton.add_transition('q2', 'q0', 'b')

      svg_output = automaton.to_svg
      doc = REXML::Document.new(svg_output)

      # Verify all transitions are rendered
      paths = REXML::XPath.match(doc, '//path[@class="transition-line"]')
      expect(paths.size).to eq(6)

      # Verify all labels are present
      labels = REXML::XPath.match(doc, '//text[@class="transition-label"]')
      label_texts = labels.map(&:text)
      expect(label_texts).to include('a', 'b')
    end
  end
end
