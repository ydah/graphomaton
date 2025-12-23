# frozen_string_literal: true

require 'graphomaton'

RSpec.describe Graphomaton::Exporters::Svg do
  let(:automaton) { Graphomaton.new }
  let(:svg_exporter) { described_class.new(automaton) }

  describe '#initialize' do
    it 'initializes with an automaton' do
      expect(svg_exporter).to be_a(described_class)
    end
  end

  describe '#export' do
    context 'with empty automaton' do
      it 'generates valid SVG' do
        svg_output = svg_exporter.export
        expect { REXML::Document.new(svg_output) }.not_to raise_error
      end

      it 'uses default dimensions' do
        svg_output = svg_exporter.export
        doc = REXML::Document.new(svg_output)
        svg = doc.root
        expect(svg.attributes['width']).to eq('800')
        expect(svg.attributes['height']).to eq('600')
      end

      it 'accepts custom dimensions' do
        svg_output = svg_exporter.export(1000, 800)
        doc = REXML::Document.new(svg_output)
        svg = doc.root
        expect(svg.attributes['width']).to eq('1000')
        expect(svg.attributes['height']).to eq('800')
      end
    end

    context 'with states and transitions' do
      before do
        automaton.add_state('A')
        automaton.add_state('B')
        automaton.add_state('C')
        automaton.set_initial('A')
        automaton.add_final('C')
        automaton.add_transition('A', 'B', 'a')
        automaton.add_transition('B', 'C', 'b')
      end

      it 'includes all states as circles' do
        svg_output = svg_exporter.export
        doc = REXML::Document.new(svg_output)
        circles = REXML::XPath.match(doc, '//circle[@class="state-circle" or contains(@class, "final-state")]')
        # Should have at least 3 circles (one per state, plus inner circle for final state)
        expect(circles.size).to be >= 3
      end

      it 'includes state labels' do
        svg_output = svg_exporter.export
        doc = REXML::Document.new(svg_output)
        labels = REXML::XPath.match(doc, '//text[@class="state-text"]')
        label_texts = labels.map(&:text)
        expect(label_texts).to include('A', 'B', 'C')
      end

      it 'includes transition labels' do
        svg_output = svg_exporter.export
        doc = REXML::Document.new(svg_output)
        labels = REXML::XPath.match(doc, '//text[@class="transition-label"]')
        label_texts = labels.map(&:text)
        expect(label_texts).to include('a', 'b')
      end
    end

    context 'with skip states transitions' do
      before do
        automaton.add_state('A')
        automaton.add_state('B')
        automaton.add_state('C')
        automaton.add_state('D')
        automaton.set_initial('A')
        automaton.add_final('D')
        automaton.add_transition('A', 'B', '1 step')
        automaton.add_transition('A', 'C', 'skip 1 state')
        automaton.add_transition('A', 'D', 'skip 2 states')
      end

      it 'creates curved paths for skip transitions' do
        svg_output = svg_exporter.export
        doc = REXML::Document.new(svg_output)
        paths = REXML::XPath.match(doc, '//path[@class="transition-line"]')
        # A->C and A->D should be curved (quadratic bezier)
        curved_paths = paths.select { |p| p.attributes['d'].include?('Q') }
        expect(curved_paths.size).to be >= 2
      end

      it 'creates different curve heights for multiple skip transitions' do
        svg_output = svg_exporter.export
        doc = REXML::Document.new(svg_output)
        paths = REXML::XPath.match(doc, '//path[@class="transition-line"]')
        curved_paths = paths.select { |p| p.attributes['d'].include?('Q') }

        # Extract control points (y-coordinates) from path data
        control_points = curved_paths.map do |path|
          d = path.attributes['d']
          # Parse "M x1 y1 Q cx cy, x2 y2" format
          match = d.match(/Q\s+([\d.]+)\s+([\d.-]+)/)
          match ? match[2].to_f : nil
        end.compact

        # Control points should be different (transitions shouldn't overlap)
        expect(control_points.uniq.size).to eq(control_points.size)
      end

      it 'includes all transition labels with proper positioning' do
        svg_output = svg_exporter.export
        doc = REXML::Document.new(svg_output)
        labels = REXML::XPath.match(doc, '//text[@class="transition-label"]')
        label_texts = labels.map(&:text).reject { |t| t == 'start' }
        expect(label_texts).to include('1 step', 'skip 1 state', 'skip 2 states')
      end
    end

    context 'with self-loop transitions' do
      before do
        automaton.add_state('A')
        automaton.add_transition('A', 'A', 'loop')
      end

      it 'creates cubic bezier curve for self-loop' do
        svg_output = svg_exporter.export
        doc = REXML::Document.new(svg_output)
        paths = REXML::XPath.match(doc, '//path[@class="transition-line"]')
        self_loop = paths.find { |p| p.attributes['d'].include?('C') }
        expect(self_loop).not_to be_nil
      end

      it 'positions label above the loop' do
        svg_output = svg_exporter.export
        doc = REXML::Document.new(svg_output)
        label = REXML::XPath.first(doc, '//text[@class="transition-label" and text()="loop"]')
        expect(label).not_to be_nil
      end
    end

    context 'with long state names' do
      before do
        automaton.add_state('VeryLongStateName')
        automaton.add_state('AnotherLongName')
      end

      it 'adjusts font size for long names' do
        svg_output = svg_exporter.export
        doc = REXML::Document.new(svg_output)
        texts = REXML::XPath.match(doc, '//text[@class="state-text"]')

        # At least one text should have reduced font size
        font_sizes = texts.map { |t| t.attributes['font-size'].to_i }
        expect(font_sizes).to include(satisfy { |size| size < 20 })
      end

      it 'renders all state names' do
        svg_output = svg_exporter.export
        doc = REXML::Document.new(svg_output)
        labels = REXML::XPath.match(doc, '//text[@class="state-text"]')
        label_texts = labels.map(&:text)
        expect(label_texts).to include('VeryLongStateName', 'AnotherLongName')
      end
    end

    context 'with non-ASCII characters' do
      before do
        automaton.add_state('状態A')
        automaton.add_state('状態B')
        automaton.add_transition('状態A', '状態B', '遷移')
      end

      it 'handles Japanese characters correctly' do
        svg_output = svg_exporter.export
        doc = REXML::Document.new(svg_output)
        labels = REXML::XPath.match(doc, '//text[@class="state-text"]')
        label_texts = labels.map(&:text)
        expect(label_texts).to include('状態A', '状態B')
      end

      it 'calculates proper text width for non-ASCII labels' do
        svg_output = svg_exporter.export
        doc = REXML::Document.new(svg_output)
        label_bg = REXML::XPath.match(doc, '//rect[@class="label-bg"]')

        # Background rectangles should have appropriate widths
        widths = label_bg.map { |rect| rect.attributes['width'].to_f }
        expect(widths).to all(be > 0)
      end
    end

    context 'with parallel transitions' do
      before do
        automaton.add_state('A')
        automaton.add_state('B')
        automaton.add_state('C')
        automaton.add_transition('A', 'C', 'skip forward')
        automaton.add_transition('C', 'A', 'skip backward')
      end

      it 'creates curved paths for bidirectional transitions' do
        svg_output = svg_exporter.export
        doc = REXML::Document.new(svg_output)
        paths = REXML::XPath.match(doc, '//path[@class="transition-line"]')
        curved_paths = paths.select { |p| p.attributes['d'].include?('Q') }
        expect(curved_paths.size).to be >= 2
      end

      it 'offsets parallel transitions to avoid overlap' do
        svg_output = svg_exporter.export
        doc = REXML::Document.new(svg_output)
        paths = REXML::XPath.match(doc, '//path[@class="transition-line"]')

        # Paths should have different control points
        control_points = paths.map do |path|
          d = path.attributes['d']
          match = d.match(/Q\s+([\d.]+)\s+([\d.-]+)/)
          match ? [match[1].to_f, match[2].to_f] : nil
        end.compact

        expect(control_points.uniq.size).to eq(control_points.size)
      end
    end
  end

  describe 'text width calculation' do
    it 'calculates width for ASCII text' do
      width = svg_exporter.send(:calculate_text_width, 'hello')
      expect(width).to be > 0
      expect(width).to be < 100
    end

    it 'calculates width for non-ASCII text' do
      width = svg_exporter.send(:calculate_text_width, 'こんにちは')
      expect(width).to be > 0
    end

    it 'calculates width for mixed text' do
      width = svg_exporter.send(:calculate_text_width, 'hello世界')
      expect(width).to be > 0
    end

    it 'returns minimum width for empty text' do
      width = svg_exporter.send(:calculate_text_width, '')
      expect(width).to eq(60)
    end

    it 'returns minimum width for very short text' do
      width = svg_exporter.send(:calculate_text_width, 'a')
      expect(width).to eq(60)
    end
  end

  describe 'state font size calculation' do
    it 'returns base size for short names' do
      size = svg_exporter.send(:calculate_state_font_size, 'A')
      expect(size).to eq(20)
    end

    it 'reduces size for long names' do
      size = svg_exporter.send(:calculate_state_font_size, 'VeryLongStateName')
      expect(size).to be < 20
    end

    it 'ensures minimum font size' do
      size = svg_exporter.send(:calculate_state_font_size, 'SuperExtremelyLongStateNameThatWouldBeVeryHardToFit')
      expect(size).to be >= 12
    end

    it 'handles non-ASCII characters' do
      size = svg_exporter.send(:calculate_state_font_size, '状態名前')
      expect(size).to be > 0
      expect(size).to be <= 20
    end
  end

  describe 'label background' do
    before do
      automaton.add_state('A')
      automaton.add_state('B')
      automaton.add_transition('A', 'B', 'test label')
    end

    it 'creates background rectangles for labels' do
      svg_output = svg_exporter.export
      doc = REXML::Document.new(svg_output)
      backgrounds = REXML::XPath.match(doc, '//rect[@class="label-bg"]')
      expect(backgrounds).not_to be_empty
    end

    it 'positions backgrounds correctly' do
      svg_output = svg_exporter.export
      doc = REXML::Document.new(svg_output)
      backgrounds = REXML::XPath.match(doc, '//rect[@class="label-bg"]')

      backgrounds.each do |bg|
        x = bg.attributes['x'].to_f
        y = bg.attributes['y'].to_f
        width = bg.attributes['width'].to_f
        height = bg.attributes['height'].to_f

        expect(x).to be_a(Float)
        expect(y).to be_a(Float)
        expect(width).to be > 0
        expect(height).to eq(20)
      end
    end
  end
end
