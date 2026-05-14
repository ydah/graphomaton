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
        svg_output = svg_exporter.export(merge_parallel_transitions: false)
        expect { REXML::Document.new(svg_output) }.not_to raise_error
      end

      it 'uses default dimensions' do
        svg_output = svg_exporter.export(merge_parallel_transitions: false)
        doc = REXML::Document.new(svg_output)
        svg = doc.root
        expect(svg.attributes['width']).to eq('800')
        expect(svg.attributes['height']).to eq('600')
      end

      it 'renders responsive SVG when requested' do
        svg_output = svg_exporter.export(responsive: true)
        doc = REXML::Document.new(svg_output)
        svg = doc.root

        expect(svg.attributes['width']).to eq('100%')
        expect(svg.attributes['height']).to eq('auto')
        expect(svg.attributes['preserveAspectRatio']).to eq('xMidYMid meet')
      end

      it 'adds accessible title and description metadata' do
        svg_output = svg_exporter.export(title: 'Order DFA', description: 'Accepts valid order events')
        doc = REXML::Document.new(svg_output)
        svg = doc.root
        title = REXML::XPath.first(doc, '//title')
        desc = REXML::XPath.first(doc, '//desc')

        expect(svg.attributes['role']).to eq('img')
        expect(svg.attributes['aria-labelledby']).to include(title.attributes['id'])
        expect(svg.attributes['aria-labelledby']).to include(desc.attributes['id'])
        expect(title.text).to eq('Order DFA')
        expect(desc.text).to eq('Accepts valid order events')
      end

      it 'accepts custom dimensions' do
        svg_output = svg_exporter.export(1000, 800)
        doc = REXML::Document.new(svg_output)
        svg = doc.root
        expect(svg.attributes['width']).to eq('1000')
        expect(svg.attributes['height']).to eq('800')
      end

      it 'uses the light theme by default' do
        svg_output = svg_exporter.export
        doc = REXML::Document.new(svg_output)
        style = REXML::XPath.first(doc, '//style')
        background = REXML::XPath.first(doc, '//rect[@class="diagram-background"]')

        expect(style.text).to include('stroke: #333')
        expect(background).to be_nil
      end

      it 'accepts named themes' do
        svg_output = svg_exporter.export(theme: :dark)
        doc = REXML::Document.new(svg_output)
        style = REXML::XPath.first(doc, '//style')
        background = REXML::XPath.first(doc, '//rect[@class="diagram-background"]')
        arrowhead = REXML::XPath.first(doc, '//marker/polygon')

        expect(style.text).to include('stroke: #e5e7eb')
        expect(background.attributes['width']).to eq('800')
        expect(background.attributes['height']).to eq('600')
        expect(arrowhead.attributes['fill']).to eq('#e5e7eb')
      end

      it 'accepts custom theme hashes' do
        custom_theme = {
          background: '#000000',
          state_fill: '#ffffff',
          stroke: '#ff0000',
          state_text: '#123456',
          transition_label: '#654321',
          label_background: '#f0f0f0',
          label_opacity: '0.88'
        }
        svg_output = svg_exporter.export(theme: custom_theme)
        doc = REXML::Document.new(svg_output)
        style = REXML::XPath.first(doc, '//style')
        background = REXML::XPath.first(doc, '//rect[@class="diagram-background"]')
        arrowhead = REXML::XPath.first(doc, '//marker/polygon')

        expect(style.text).to include('stroke: #ff0000')
        expect(style.text).to include('fill: #f0f0f0')
        expect(background.attributes['width']).to eq('800')
        expect(arrowhead.attributes['fill']).to eq('#ff0000')
      end

      it 'raises for unknown custom theme keys' do
        expect { svg_exporter.export(theme: { stroke: '#000', unknown_key: '#fff' }) }
          .to raise_error(ArgumentError, /Unknown SVG theme keys: unknown_key/)
      end

      it 'accepts string theme names' do
        svg_output = svg_exporter.export(theme: 'forest')
        doc = REXML::Document.new(svg_output)
        style = REXML::XPath.first(doc, '//style')

        expect(style.text).to include('stroke: #166534')
      end

      it 'raises an error for unknown themes' do
        expect { svg_exporter.export(theme: :unknown) }.to raise_error(
          ArgumentError,
          /Unknown SVG theme: :unknown/
        )
      end

      it 'raises for unsupported direction' do
        expect { svg_exporter.export(direction: :up) }.to raise_error(
          ArgumentError,
          /Unknown direction: :up/
        )
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

      it 'supports direction option for state layout' do
        svg_output = svg_exporter.export(800, 600, direction: :tb)
        doc = REXML::Document.new(svg_output)
        circles = REXML::XPath.match(doc, '//circle[@class="state-circle"]')

        expect(circles.size).to be >= 3
        expect(circles[0].attributes['cy'].to_f).to be < circles[1].attributes['cy'].to_f
      end

      it 'supports circle layout' do
        svg_output = svg_exporter.export(800, 600, layout: :circle)
        doc = REXML::Document.new(svg_output)
        circles = REXML::XPath.match(doc, '//circle[@class="state-circle"]')
        x_values = circles.map { |c| c.attributes['cx'].to_f }.uniq
        y_values = circles.map { |c| c.attributes['cy'].to_f }.uniq

        expect(x_values.size).to be > 1
        expect(y_values.size).to be > 1
      end

      it 'supports grid layout' do
        svg_output = svg_exporter.export(800, 600, layout: :grid)
        doc = REXML::Document.new(svg_output)
        circles = REXML::XPath.match(doc, '//circle[@class="state-circle"]')
        x_values = circles.map { |c| c.attributes['cx'].to_f }.uniq
        y_values = circles.map { |c| c.attributes['cy'].to_f }.uniq

        expect(x_values.size).to be > 1
        expect(y_values.size).to be > 1
      end

      it 'supports layered layout' do
        svg_output = svg_exporter.export(800, 600, layout: :layered)
        doc = REXML::Document.new(svg_output)
        circles = REXML::XPath.match(doc, '//circle[@class="state-circle"]')

        expect(circles.size).to be >= 3
      end

      it 'supports force layout' do
        svg_output = svg_exporter.export(800, 600, layout: :force, force_iterations: 10, layout_seed: 1)
        doc = REXML::Document.new(svg_output)
        circles = REXML::XPath.match(doc, '//circle[@class="state-circle"]')

        expect(circles.size).to be >= 3
        x_positions = circles.map { |c| c.attributes['cx'].to_f }
        y_positions = circles.map { |c| c.attributes['cy'].to_f }

        expect((x_positions.uniq.size > 1) || (y_positions.uniq.size > 1)).to be true
      end

      it 'supports force layout tuning options' do
        expect {
          svg_exporter.export(
            900,
            700,
            layout: :force,
            node_spacing: 180,
            padding: 120,
            force_iterations: 8,
            layout_seed: 7
          )
        }.not_to raise_error
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

      it 'supports custom state radius' do
        svg_output = svg_exporter.export(state_radius: 22)
        doc = REXML::Document.new(svg_output)
        circles = REXML::XPath.match(doc, '//circle[@class="state-circle"]')

        expect(circles.first.attributes['r'].to_f).to eq(22.0)
      end

      it 'supports cubic spline edge style' do
        spline = Graphomaton.new
        spline.add_state('A', 100, 100)
        spline.add_state('B', 260, 180)
        spline.add_transition('A', 'B', 'spline')

        svg_output = described_class.new(spline).export(layout: :manual, edge_style: :spline)
        doc = REXML::Document.new(svg_output)
        path = REXML::XPath.first(doc, '//path[@class="transition-line"]')

        expect(path.attributes['d']).to include(' C ')
      end

      it 'can grow state radius from label width when enabled' do
        long_label = Graphomaton.new
        long_label.add_state('q_long', label: 'VeryLongStateNameForRadius')

        svg_output = described_class.new(long_label).export(auto_state_radius: true, max_state_radius: 90)
        doc = REXML::Document.new(svg_output)
        circle = REXML::XPath.first(doc, '//circle[@class="state-circle"]')

        expect(circle.attributes['r'].to_f).to be > described_class::DEFAULT_STATE_RADIUS
      end

      it 'clamps automatic state radius to configured bounds' do
        long_label = Graphomaton.new
        long_label.add_state('q_long', label: 'ExtremelyLongStateNameThatWouldOtherwiseGrowTooMuch')

        svg_output = described_class.new(long_label).export(
          auto_state_radius: true,
          min_state_radius: 44,
          max_state_radius: 48
        )
        doc = REXML::Document.new(svg_output)
        circle = REXML::XPath.first(doc, '//circle[@class="state-circle"]')

        expect(circle.attributes['r'].to_f).to eq(48.0)
      end

      it 'supports animated pulse state effect with reduced motion fallback' do
        svg_output = svg_exporter.export(state_effect: :pulse)
        doc = REXML::Document.new(svg_output)
        style = REXML::XPath.first(doc, '//style')

        expect(style.text).to include('graphomaton-pulse')
        expect(style.text).to include('prefers-reduced-motion')
        expect(style.text).to include('animation: graphomaton-pulse')
      end

      it 'can render without preserving manual state positions' do
        manual = Graphomaton.new
        manual.add_state('A', 10, 10)
        manual.add_state('B')
        manual.set_initial('A')

        svg_output = described_class.new(manual).export(800, 600, preserve_manual_positions: false)
        doc = REXML::Document.new(svg_output)
        state_a = REXML::XPath.first(doc, '//g[@id="state-a"]/circle')

        expect(state_a.attributes['cx'].to_f).not_to eq(10.0)
      end

      it 'can fit rendered manual positions into the SVG viewBox' do
        manual = Graphomaton.new
        manual.add_state('A', -1000, 0)
        manual.add_state('B', 1000, 0)

        svg_output = described_class.new(manual).export(800, 600, layout: :manual, fit: :contain)
        doc = REXML::Document.new(svg_output)
        circles = REXML::XPath.match(doc, '//circle[@class="state-circle"]')
        x_values = circles.map { |circle| circle.attributes['cx'].to_f }

        expect(x_values.min).to be >= 80
        expect(x_values.max).to be <= 720
      end

      it 'can cover the SVG viewBox with rendered manual positions' do
        manual = Graphomaton.new
        manual.add_state('A', 0, 0)
        manual.add_state('B', 1000, 100)

        svg_output = described_class.new(manual).export(800, 600, layout: :manual, fit: :cover)
        doc = REXML::Document.new(svg_output)
        circles = REXML::XPath.match(doc, '//circle[@class="state-circle"]')
        x_values = circles.map { |circle| circle.attributes['cx'].to_f }
        y_values = circles.map { |circle| circle.attributes['cy'].to_f }

        expect(x_values.min).to eq(80.0)
        expect(x_values.max).to eq(720.0)
        expect(y_values.min).to eq(80.0)
        expect(y_values.max).to eq(520.0)
      end

      it 'accepts a stable SVG id prefix for root and marker definitions' do
        svg_output = svg_exporter.export(svg_id: 'diagram-main')
        doc = REXML::Document.new(svg_output)
        svg = doc.root
        marker = REXML::XPath.first(doc, '//marker')
        style = REXML::XPath.first(doc, '//style')

        expect(svg.attributes['id']).to eq('diagram-main')
        expect(marker.attributes['id']).to eq('diagram-main-arrowhead')
        expect(style.text).to include('marker-end: url(#diagram-main-arrowhead)')
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

    context 'with multiple self-loops' do
      before do
        automaton.add_state('B')
        automaton.add_transition('B', 'B', 'loop-right')
        automaton.add_transition('B', 'B', 'loop-bottom')
        automaton.add_transition('B', 'B', 'loop-left')
        automaton.add_transition('B', 'B', 'loop-top')
      end

      it 'distributes loops around state' do
        svg_output = svg_exporter.export(merge_parallel_transitions: false)
        doc = REXML::Document.new(svg_output)
        paths = REXML::XPath.match(doc, '//path[@class="transition-line"]')

        expect(paths.select { |p| p.attributes['d'].include?('C') }.size).to eq(4)

        labels = REXML::XPath.match(doc, '//text[@class="transition-label"]')
        loop_labels = labels.select { |label| label.text&.start_with?('loop') }
        x_positions = loop_labels.map { |label| label.attributes['x'].to_f }
        y_positions = loop_labels.map { |label| label.attributes['y'].to_f }

        expect(x_positions.uniq.size).to be > 1
        expect(y_positions.uniq.size).to be > 1
      end

      it 'merges parallel self-loops by default' do
        svg_output = svg_exporter.export
        doc = REXML::Document.new(svg_output)
        paths = REXML::XPath.match(doc, '//path[@class="transition-line"]')
        self_loop_labels = REXML::XPath.match(doc, '//text[@class="transition-label"]')

        expect(paths.select { |path| path.attributes['d'].include?('C') }.size).to eq(1)
        merged_labels = self_loop_labels.map(&:text).join(',')
        expect(merged_labels).to include('loop-right', 'loop-bottom', 'loop-left', 'loop-top')
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

      it 'wraps state labels into multiple lines when enabled' do
        svg_output = svg_exporter.export(state_wrap: true, max_state_label_width: 40)
        doc = REXML::Document.new(svg_output)
        state_texts = REXML::XPath.match(doc, '//text[@class="state-text"]')

        expect(state_texts.any? { |state_text| !state_text.get_elements('tspan').empty? }).to be true
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

    context 'with XML-sensitive characters' do
      before do
        automaton.add_state('A&B', label: '<Start & "quoted">', metadata: { tooltip: 'State <tooltip> & docs' })
        automaton.add_state('B')
        automaton.add_transition('A&B', 'B', 'x < y & z', metadata: { tooltip: 'Edge <tooltip> & docs' })
      end

      it 'escapes state labels, transition labels, and tooltip text into valid SVG' do
        svg_output = svg_exporter.export
        doc = REXML::Document.new(svg_output)
        text_nodes = REXML::XPath.match(doc, '//text')
        title_nodes = REXML::XPath.match(doc, '//title')

        expect(text_nodes.map(&:text)).to include('<Start & "quoted">', 'x < y & z')
        expect(title_nodes.map(&:text)).to include('State <tooltip> & docs', 'Edge <tooltip> & docs')
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

    it 'uses wider metrics for Japanese characters than ASCII characters' do
      ascii_width = svg_exporter.send(:calculate_text_width, 'abcdefgh')
      japanese_width = svg_exporter.send(:calculate_text_width, '状態遷移状態遷移')

      expect(japanese_width).to be > ascii_width
    end

    it 'does not overestimate latin accents or combining marks as full-width characters' do
      ascii_width = svg_exporter.send(:calculate_text_width, 'cafe cafe cafe')
      accented_width = svg_exporter.send(:calculate_text_width, 'café café café')
      combining_width = svg_exporter.send(:calculate_text_width, "cafe\u0301 cafe\u0301 cafe\u0301")

      expect(accented_width).to be_within(6).of(ascii_width)
      expect(combining_width).to be_within(1).of(ascii_width)
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

  context 'with transition label wrapping' do
    before do
      automaton.add_state('A')
      automaton.add_state('B')
      automaton.add_transition('A', 'B', 'this label should be wrapped into multiple rows when configured')
    end

    it 'adds wrapped transition labels with multiple tspans' do
      svg_output = svg_exporter.export(wrap: true, max_transition_label_width: 90)
      doc = REXML::Document.new(svg_output)
      labels = REXML::XPath.match(doc, '//text[@class="transition-label"]')

      has_wrapped_label = labels.any? { |label| !label.get_elements('tspan').empty? }
      expect(has_wrapped_label).to be true
    end

    it 'can rotate transition labels along edges' do
      rotated = Graphomaton.new
      rotated.add_state('A', 100, 100)
      rotated.add_state('B', 260, 180)
      rotated.add_transition('A', 'B', 'diagonal')

      svg_output = described_class.new(rotated).export(layout: :manual, edge_style: :straight, rotate_labels: true)
      doc = REXML::Document.new(svg_output)
      label = REXML::XPath.first(doc, '//text[@class="transition-label"]')
      background = REXML::XPath.first(doc, '//rect[@class="label-bg"]')

      expect(label.attributes['transform']).to include('rotate(')
      expect(background.attributes['transform']).to eq(label.attributes['transform'])
    end
  end

  describe '#collision_free_label_box' do
    it 'adjusts box position when overlap is detected' do
      svg_exporter.send(:instance_variable_set, :@label_boxes, [
        { x: 10.0, y: 10.0, width: 80.0, height: 20.0 }
      ])
      svg_exporter.send(:instance_variable_set, :@positions, {})

      base_box = { x: 20.0, y: 15.0, width: 40.0, height: 20.0 }
      resolved = svg_exporter.send(:collision_free_label_box, base_box)

      moved = (resolved[:x] != base_box[:x]) || (resolved[:y] != base_box[:y])
      expect(moved).to be true
    end
  end
end
