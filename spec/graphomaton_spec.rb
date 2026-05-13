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

      it 'supports directional layout' do
        automaton.auto_layout(800, 600, direction: :tb)

        expect(automaton.states['q0'][:y]).to be < automaton.states['q1'][:y]
        expect(automaton.states['q1'][:y]).to be < automaton.states['q2'][:y]
      end

      it 'supports circle layout' do
        automaton.auto_layout(800, 600, layout: :circle)
        x_values = automaton.states.values.map { |s| s[:x] }
        y_values = automaton.states.values.map { |s| s[:y] }

        expect(x_values.uniq.size).to be > 1
        expect(y_values.uniq.size).to be > 1
      end

      it 'supports grid layout' do
        automaton.auto_layout(800, 600, layout: :grid)
        x_values = automaton.states.values.map { |s| s[:x] }
        y_values = automaton.states.values.map { |s| s[:y] }

        expect(x_values.uniq.size).to be > 1
        expect(y_values.uniq.size).to be > 1
      end

      it 'supports layered layout' do
        automaton.add_transition('q0', 'q1', 'a')
        automaton.auto_layout(800, 600, layout: :layered)

        expect(automaton.states['q0'][:x]).not_to be_nil
        expect(automaton.states['q1'][:x]).not_to be_nil
        expect(automaton.states['q2'][:x]).not_to be_nil
      end

      it 'separates disconnected components in layered layout' do
        automaton.set_initial('q0')
        automaton.add_state('q3')
        automaton.add_state('q4')
        automaton.add_transition('q3', 'q4', 'c')

        automaton.auto_layout(800, 600, layout: :layered, direction: :lr)

        x_values = [automaton.states['q0'], automaton.states['q1'], automaton.states['q2'], automaton.states['q3'], automaton.states['q4']].map { |state| state[:x] }
        expect(x_values.uniq.size).to be > 2
      end

      it 'supports force layout' do
        automaton.auto_layout(800, 600, layout: :force)

        values = automaton.states.values
        expect(values.map { |state| state[:x] }).to all(be_a(Numeric))
        expect(values.map { |state| state[:y] }).to all(be_a(Numeric))
        expect(values.map { |state| state[:x] }.uniq.size).to be > 1
      end

      it 'supports layout tuning options for force layout' do
        svg_output = automaton.to_svg(
          900,
          700,
          layout: :force,
          node_spacing: 160,
          force_iterations: 10,
          layout_seed: 42
        )

        expect { REXML::Document.new(svg_output) }.not_to raise_error
      end

      it 'keeps manual coordinates with directional layout' do
        automaton.add_state('q3', 500, 400)
        automaton.auto_layout(800, 600, direction: :bt)

        expect(automaton.states['q3'][:x]).to eq(500)
        expect(automaton.states['q3'][:y]).to eq(400)
        expect(automaton.states['q0'][:y]).to be > automaton.states['q1'][:y]
      end

      it 'keeps auto layout non-destructive for render-only operations' do
        automaton = described_class.new
        automaton.add_state('q0')
        automaton.add_state('q1')
        automaton.set_initial('q0')
        automaton.add_transition('q0', 'q1', 'a')

        _first = automaton.to_svg(800, 600)
        _second = automaton.to_svg(1200, 900)

        expect(automaton.states['q0'][:x]).to be_nil
        expect(automaton.states['q0'][:y]).to be_nil
        expect(automaton.states['q1'][:x]).to be_nil
        expect(automaton.states['q1'][:y]).to be_nil
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

    it 'applies custom themes' do
      svg_output = automaton.to_svg(theme: :ocean)
      doc = REXML::Document.new(svg_output)
      style = REXML::XPath.first(doc, '//style')
      background = REXML::XPath.first(doc, '//rect[@class="diagram-background"]')

      expect(style.text).to include('stroke: #0369a1')
      expect(background).not_to be_nil
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
      expect(paths.size).to eq(0) # Two transitions
    end

    it 'does not mutate inferred coordinates on repeated render' do
      automaton.to_svg(800, 600)
      expect(automaton.states['q0'][:x]).to be_nil
      expect(automaton.states['q1'][:x]).to be_nil

      automaton.to_svg(1200, 900)
      expect(automaton.states['q0'][:x]).to be_nil
      expect(automaton.states['q1'][:x]).to be_nil
    end

    it 'keeps manually provided coordinates when rendering' do
      automaton.add_state('q3', 100, 120)
      automaton.add_transition('q2', 'q3', 'c')
      automaton.to_svg

      expect(automaton.states['q3'][:x]).to eq(100)
      expect(automaton.states['q3'][:y]).to eq(120)
    end

    it 'supports direction option' do
      svg_output = automaton.to_svg(800, 600, direction: :tb)
      doc = REXML::Document.new(svg_output)
      circles = REXML::XPath.match(doc, '//circle[@class="state-circle"]')

      expect(circles.size).to be >= 3
      expect(circles[0].attributes['cy'].to_f).to be < circles[1].attributes['cy'].to_f
      expect(circles[1].attributes['cy'].to_f).to be < circles[2].attributes['cy'].to_f
    end

    it 'supports responsive output' do
      svg_output = automaton.to_svg(800, 600, responsive: true)
      doc = REXML::Document.new(svg_output)
      svg = doc.root

      expect(svg.attributes['width']).to eq('100%')
      expect(svg.attributes['height']).to eq('auto')
      expect(svg.attributes['preserveAspectRatio']).to eq('xMidYMid meet')
    end

    it 'creates text labels for transitions' do
      svg_output = automaton.to_svg
      doc = REXML::Document.new(svg_output)
      labels = REXML::XPath.match(doc, '//text[@class="transition-label"]')
      expect(labels.map(&:text)).to include('a', 'b')
    end

    it 'supports force layout' do
      svg_output = automaton.to_svg(800, 600, layout: :force)
      doc = REXML::Document.new(svg_output)
      circles = REXML::XPath.match(doc, '//circle[@class="state-circle"]')

      expect(circles.size).to be >= 3
      x_positions = circles.map { |c| c.attributes['cx'].to_f }
      y_positions = circles.map { |c| c.attributes['cy'].to_f }

      expect((x_positions.uniq.size > 1) || (y_positions.uniq.size > 1)).to be true
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
        expect(curved_paths.size).to be >= 1
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

    it 'respects custom themes' do
      automaton.save_svg(temp_file, theme: :forest)
      content = File.read(temp_file)

      expect(content).to include('#166534')
    end
  end

  describe '#to_html and #save_html' do
    let(:temp_file) { 'test_output.html' }

    after do
      FileUtils.rm_f(temp_file)
    end

    before do
      automaton.add_state('q0')
      automaton.add_state('q1')
      automaton.add_transition('q0', 'q1', 'a')
    end

    it 'generates HTML with custom options' do
      html_output = automaton.to_html(theme: :dark, offline: true, cdn: '/assets/mermaid.min.js', lang: 'en', title: 'Automaton')
      expect(html_output).to include('<html lang="en">')
      expect(html_output).to include('<title>Automaton</title>')
      expect(html_output).to include('theme: \'dark\'')
      expect(html_output).to include('<script src="/assets/mermaid.min.js"></script>')
    end

    it 'saves HTML to file' do
      automaton.save_html(temp_file, theme: :forest, title: 'Saved')
      content = File.read(temp_file)

      expect(content).to include('<title>Saved</title>')
      expect(content).to include('cdn.jsdelivr.net')
    end
  end

  describe '#to_png' do
    before do
      automaton.add_state('q0')
      automaton.add_state('q1')
      automaton.add_transition('q0', 'q1', 'a')
    end

    it 'generates PNG bytes' do
      png_output = Graphomaton::Exporters::Png::PNG_SIGNATURE + 'png-data'.b
      png_exporter = instance_double(Graphomaton::Exporters::Png)

      expect(Graphomaton::Exporters::Png).to receive(:new).with(automaton).and_return(png_exporter)
      expect(png_exporter).to receive(:export).with(1000, 800, theme: :dark).and_return(png_output)

      expect(automaton.to_png(1000, 800, theme: :dark)).to eq(png_output)
    end
  end

  describe '#save_png' do
    let(:temp_file) { 'test_output.png' }

    after do
      FileUtils.rm_f(temp_file)
    end

    before do
      automaton.add_state('q0')
      automaton.add_state('q1')
      automaton.add_transition('q0', 'q1', 'a')
    end

    it 'saves PNG bytes to file' do
      png_output = Graphomaton::Exporters::Png::PNG_SIGNATURE + 'png-data'.b
      allow(automaton).to receive(:to_png).with(1200, 900, theme: :forest).and_return(png_output)

      automaton.save_png(temp_file, 1200, 900, theme: :forest)

      expect(File.binread(temp_file)).to eq(png_output)
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
      expect(paths.size).to eq(4)

      # Verify all labels are present
      labels = REXML::XPath.match(doc, '//text[@class="transition-label"]')
      label_texts = labels.map(&:text)
      expect(label_texts).to include('a', 'b')
    end
  end
end
