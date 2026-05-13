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

  describe '.png_available?' do
    it 'delegates to the PNG exporter availability check' do
      allow(Graphomaton::Exporters::Png).to receive(:available?).with(converter: :magick).and_return(true)

      expect(described_class.png_available?(converter: :magick)).to be true
    end
  end

  describe '.pdf_available?' do
    it 'delegates to the PDF exporter availability check' do
      allow(Graphomaton::Exporters::Pdf).to receive(:available?).with(converter: :magick).and_return(true)

      expect(described_class.pdf_available?(converter: :magick)).to be true
    end
  end

  describe '.webp_available?' do
    it 'delegates to the WebP exporter availability check' do
      allow(Graphomaton::Exporters::Webp).to receive(:available?).with(converter: :magick).and_return(true)

      expect(described_class.webp_available?(converter: :magick)).to be true
    end
  end

  describe '.from_hash, .from_json, and .from_yaml' do
    let(:input_hash) do
      {
        states: [
          { id: 'q0', label: 'Start', initial: true },
          { id: 'q1', final: true, metadata: { tooltip: 'Accept' } }
        ],
        transitions: [
          { from: 'q0', to: 'q1', label: 'a', line_style: 'dashed' }
        ]
      }
    end

    it 'builds an automaton from a hash' do
      automaton = described_class.from_hash(input_hash)

      expect(automaton.states['q0']).to include(label: 'Start')
      expect(automaton.initial_state).to eq('q0')
      expect(automaton.final_states).to eq(['q1'])
      expect(automaton.transitions).to include(from: 'q0', to: 'q1', label: 'a', line_style: 'dashed')
    end

    it 'builds an automaton from JSON' do
      automaton = described_class.from_json(JSON.generate(input_hash))

      expect(automaton.states.keys).to contain_exactly('q0', 'q1')
      expect(automaton.transitions.first[:label]).to eq('a')
    end

    it 'builds an automaton from YAML' do
      automaton = described_class.from_yaml(input_hash.to_yaml)

      expect(automaton.states.keys).to contain_exactly('q0', 'q1')
      expect(automaton.final_states).to eq(['q1'])
    end

    it 'rejects malformed input' do
      expect do
        described_class.from_hash(states: [{ label: 'missing id' }])
      end.to raise_error(ArgumentError, /requires id or name/)
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

    it 'supports optional display label, style, and metadata' do
      automaton.add_state('q0', label: 'Start', style: { fill: '#fee2e2' }, metadata: { role: 'entry' }, shape: :ellipse)

      expect(automaton.states['q0']).to include(
        label: 'Start',
        style: { fill: '#fee2e2' },
        metadata: { role: 'entry' },
        shape: :ellipse
      )
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

    it 'normalizes array labels' do
      automaton.add_transition('q0', 'q1', %w[a b a])

      expect(automaton.transitions).to include({ from: 'q0', to: 'q1', label: 'a, b' })
    end

    it 'can sort array labels when requested' do
      automaton.add_transition('q0', 'q1', %w[b a b], sort_labels: true)

      expect(automaton.transitions).to include({ from: 'q0', to: 'q1', label: 'a, b' })
    end

    it 'normalizes epsilon transition labels' do
      automaton.add_transition('q0', 'q1', :epsilon)
      automaton.add_transition('q1', 'q0', [:epsilon, 'a'], epsilon_label: 'eps')

      expect(automaton.transitions).to include({ from: 'q0', to: 'q1', label: Graphomaton::DEFAULT_EPSILON_LABEL })
      expect(automaton.transitions).to include({ from: 'q1', to: 'q0', label: 'eps, a' })
    end

    it 'supports optional transition style, line style, and metadata' do
      automaton.add_transition(
        'q0',
        'q1',
        'a',
        style: { stroke: '#ef4444' },
        line_style: :dashed,
        metadata: { tooltip: 'Hot path' }
      )

      expect(automaton.transitions).to include(
        from: 'q0',
        to: 'q1',
        label: 'a',
        style: { stroke: '#ef4444' },
        line_style: :dashed,
        metadata: { tooltip: 'Hot path' }
      )
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

  describe '#validate!' do
    it 'returns true for a valid automaton' do
      automaton.add_state('q0')
      automaton.add_state('q1')
      automaton.set_initial('q0')
      automaton.add_final('q1')
      automaton.add_transition('q0', 'q1', 'a')

      expect(automaton.valid?).to be true
      expect(automaton.validate!).to be true
    end

    it 'reports undefined initial, final, and transition states' do
      automaton.add_state('q0')
      automaton.set_initial('missing_start')
      automaton.add_final('missing_final')
      automaton.add_transition('q0', 'missing_target', 'a')
      automaton.add_transition('missing_source', 'q0', 'b')

      expect(automaton.valid?).to be false
      expect(automaton.validation_errors).to include('Initial state "missing_start" is not defined')
      expect do
        automaton.validate!
      end.to raise_error(Graphomaton::ValidationError, /missing_target/)
    end
  end

  describe '#reachable_states and #unreachable_states' do
    it 'reports states reachable from the initial state' do
      automaton.add_state('q0')
      automaton.add_state('q1')
      automaton.add_state('q2')
      automaton.set_initial('q0')
      automaton.add_transition('q0', 'q1', 'a')

      expect(automaton.reachable_states).to contain_exactly('q0', 'q1')
      expect(automaton.unreachable_states).to eq(['q2'])
    end
  end

  describe '#states_reaching_final, #dead_states, and #trap_states' do
    it 'reports states that cannot reach a final state and trap states' do
      automaton.add_state('q0')
      automaton.add_state('q1')
      automaton.add_state('dead')
      automaton.add_state('trap')
      automaton.set_initial('q0')
      automaton.add_final('q1')
      automaton.add_transition('q0', 'q1', 'accept')
      automaton.add_transition('dead', 'trap', 'fallthrough')
      automaton.add_transition('trap', 'trap', 'loop')

      expect(automaton.states_reaching_final).to contain_exactly('q0', 'q1')
      expect(automaton.live_states).to contain_exactly('q0', 'q1')
      expect(automaton.dead_states).to contain_exactly('dead', 'trap')
      expect(automaton.trap_states).to contain_exactly('trap')
    end

    it 'does not report every state as dead when no final state exists' do
      automaton.add_state('q0')
      automaton.add_state('q1')
      automaton.add_transition('q0', 'q1', 'a')

      expect(automaton.dead_states).to be_empty
    end
  end

  describe '#layout_warnings' do
    it 'returns warnings for states that may be clipped by the canvas' do
      automaton.add_state('q0', 10, 10)

      warnings = automaton.layout_warnings(200, 200)

      expect(warnings).to include('State "q0" may be clipped horizontally')
      expect(warnings).to include('State "q0" may be clipped vertically')
    end

    it 'returns no warnings when states fit inside the canvas' do
      automaton.add_state('q0', 100, 100)

      expect(automaton.layout_warnings(200, 200)).to be_empty
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

      it 'supports bfs layout as a layered graph layout' do
        automaton.add_transition('q0', 'q1', 'a')
        automaton.add_transition('q1', 'q2', 'b')
        automaton.auto_layout(800, 600, layout: :bfs, direction: :lr)

        expect(automaton.states['q0'][:x]).to be < automaton.states['q1'][:x]
        expect(automaton.states['q1'][:x]).to be < automaton.states['q2'][:x]
      end

      it 'supports manual layout when every state has explicit coordinates' do
        manual = described_class.new
        manual.add_state('q0', 100, 120)
        manual.add_state('q1', 240, 120)

        manual.auto_layout(800, 600, layout: :manual)

        expect(manual.states['q0']).to include(x: 100, y: 120)
        expect(manual.states['q1']).to include(x: 240, y: 120)
      end

      it 'rejects manual layout when a state is missing explicit coordinates' do
        manual = described_class.new
        manual.add_state('q0', 100, 120)
        manual.add_state('q1')

        expect do
          manual.auto_layout(800, 600, layout: :manual)
        end.to raise_error(ArgumentError, /Manual layout requires explicit coordinates for: q1/)
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

      it 'moves final states to the end on linear layout' do
        local = described_class.new
        local.add_state('q0')
        local.add_state('q1')
        local.add_state('q2')
        local.add_final('q1')
        local.set_initial('q0')

        local.auto_layout(1200, 600, layout: :linear, direction: :lr, final_position: :end)

        expect(local.states['q1'][:x]).to be > [local.states['q0'][:x], local.states['q2'][:x]].max
      end

      it 'moves final states to the final layer in layered layout' do
        local = described_class.new
        local.add_state('q0')
        local.add_state('q1')
        local.add_state('q2')
        local.set_initial('q0')
        local.add_final('q2')

        local.add_transition('q0', 'q1', 'a')
        local.add_transition('q0', 'q2', 'b')

        local.auto_layout(800, 600, layout: :layered, direction: :lr, final_position: :end)

        expect(local.states['q2'][:x]).to be > local.states['q1'][:x]
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

      it 'recomputes auto layout coordinates on repeated calls while preserving manual positions' do
        automaton = described_class.new
        automaton.add_state('q0', 70, 120)
        automaton.add_state('q1')
        automaton.add_state('q2')
        automaton.add_state('q3')
        automaton.set_initial('q0')

        automaton.auto_layout(220, 300, layout: :linear, direction: :lr, node_spacing: 200)
        first = automaton.states.values_at('q1', 'q2', 'q3').map { |state| [state[:x], state[:y]] }

        automaton.auto_layout(800, 300, layout: :linear, direction: :lr, node_spacing: 200)
        second = automaton.states.values_at('q1', 'q2', 'q3').map { |state| [state[:x], state[:y]] }

        expect(automaton.states['q0'][:x]).to eq(70)
        expect(automaton.states['q0'][:y]).to eq(120)
        expect(first).not_to eq(second)
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

    it 'can include an XML declaration' do
      svg_output = automaton.to_svg(xml_declaration: true)

      expect(svg_output).to start_with('<?xml version="1.0" encoding="UTF-8"?>')
    end

    it 'can pretty print SVG output' do
      svg_output = automaton.to_svg(pretty: true)

      expect { REXML::Document.new(svg_output) }.not_to raise_error
      expect(svg_output).to include("\n  <")
    end

    it 'can minify SVG output' do
      svg_output = automaton.to_svg(minify: true)

      expect { REXML::Document.new(svg_output) }.not_to raise_error
      expect(svg_output).not_to include("\n      .")
    end

    it 'rejects conflicting SVG serialization options' do
      expect do
        automaton.to_svg(pretty: true, minify: true)
      end.to raise_error(ArgumentError, /pretty and minify/)
    end

    it 'includes marker definition for arrowheads' do
      svg_output = automaton.to_svg
      doc = REXML::Document.new(svg_output)
      marker = REXML::XPath.first(doc, '//marker')
      style = REXML::XPath.first(doc, '//style')

      expect(marker).not_to be_nil
      expect(marker.attributes['id']).to start_with(doc.root.attributes['id'])
      expect(style.text).to include("url(##{marker.attributes['id']})")
    end

    it 'supports custom arrowhead size' do
      svg_output = automaton.to_svg(800, 600, arrow_size: 16)
      doc = REXML::Document.new(svg_output)
      marker = REXML::XPath.first(doc, '//marker')

      expect(marker.attributes['markerWidth']).to eq('16.0')
      expect(marker.attributes['markerUnits']).to eq('strokeWidth')
    end

    it 'supports custom arrowhead shapes' do
      svg_output = automaton.to_svg(800, 600, arrow_shape: :vee)
      doc = REXML::Document.new(svg_output)
      marker = REXML::XPath.first(doc, '//marker')

      expect(REXML::XPath.first(marker, './polyline')).not_to be_nil
    end

    it 'supports custom state and transition stroke widths' do
      svg_output = automaton.to_svg(state_stroke_width: 3, transition_stroke_width: 2)
      doc = REXML::Document.new(svg_output)
      style = REXML::XPath.first(doc, '//style')

      expect(style.text).to include('stroke-width: 3.0')
      expect(style.text).to include('stroke-width: 2.0')
    end

    it 'supports custom SVG font family and weights' do
      svg_output = automaton.to_svg(
        font_family: '"Noto Sans JP", sans-serif',
        state_font_weight: 700,
        transition_font_weight: 500
      )
      doc = REXML::Document.new(svg_output)
      style = REXML::XPath.first(doc, '//style')

      expect(style.text).to include('font-family: "Noto Sans JP", sans-serif')
      expect(style.text).to include('font-weight: 700')
      expect(style.text).to include('font-weight: 500')
    end

    it 'includes styles' do
      svg_output = automaton.to_svg
      doc = REXML::Document.new(svg_output)
      style = REXML::XPath.first(doc, '//style')
      expect(style).not_to be_nil
      expect(style.text).to include('state-circle')
    end

    it 'can omit embedded styles for external CSS' do
      svg_output = automaton.to_svg(embed_styles: false)
      doc = REXML::Document.new(svg_output)

      expect(REXML::XPath.first(doc, '//style')).to be_nil
      expect(REXML::XPath.first(doc, '//g[@class="states"]')).not_to be_nil
    end

    it 'includes generator metadata' do
      svg_output = automaton.to_svg
      doc = REXML::Document.new(svg_output)
      metadata = REXML::XPath.first(doc, '//metadata/graphomaton')

      expect(metadata.attributes['generator']).to eq('graphomaton')
      expect(metadata.attributes['version']).to eq(Graphomaton::VERSION)
      expect(metadata.attributes['format']).to eq('svg')
    end

    it 'keeps stroke widths stable when SVG is scaled' do
      svg_output = automaton.to_svg(responsive: true)
      doc = REXML::Document.new(svg_output)
      style = REXML::XPath.first(doc, '//style')

      expect(style.text).to include('vector-effect: non-scaling-stroke')
    end

    it 'can expose SVG theme values as CSS variables' do
      svg_output = automaton.to_svg(css_variables: true)
      doc = REXML::Document.new(svg_output)
      svg = doc.root
      style = REXML::XPath.first(doc, '//style')

      expect(svg.attributes['id']).to include('graphomaton-')
      expect(style.text).to include('--graphomaton-state-fill')
      expect(style.text).to include('var(--graphomaton-state-fill')
    end

    it 'includes rendering hints for SVG shapes and text' do
      svg_output = automaton.to_svg
      doc = REXML::Document.new(svg_output)
      style = REXML::XPath.first(doc, '//style')

      expect(style.text).to include('shape-rendering: geometricPrecision')
      expect(style.text).to include('text-rendering: geometricPrecision')
      expect(style.text).to include('stroke-linecap: round')
    end

    it 'groups transitions and states for SVG styling' do
      svg_output = automaton.to_svg
      doc = REXML::Document.new(svg_output)

      expect(REXML::XPath.first(doc, '//g[@class="transitions"]')).not_to be_nil
      expect(REXML::XPath.first(doc, '//g[@class="states"]')).not_to be_nil
    end

    it 'adds stable ids and data attributes for states and transitions' do
      svg_output = automaton.to_svg
      doc = REXML::Document.new(svg_output)
      state = REXML::XPath.first(doc, '//g[@id="state-q0"]')
      transition = REXML::XPath.first(doc, '//g[@id="transition-q0-q1-a"]')

      expect(state.attributes['data-state']).to eq('q0')
      expect(transition.attributes['data-from']).to eq('q0')
      expect(transition.attributes['data-to']).to eq('q1')
      expect(transition.attributes['data-label']).to eq('a')
    end

    it 'renders transition styles and metadata tooltips in SVG output' do
      local = described_class.new
      local.add_state('q0')
      local.add_state('q1')
      local.add_transition('q0', 'q1', 'a', style: { stroke: '#ef4444', stroke_width: 3 }, line_style: :dashed, metadata: { tooltip: 'Hot path' })

      svg_output = local.to_svg
      doc = REXML::Document.new(svg_output)
      transition = REXML::XPath.first(doc, '//g[@id="transition-q0-q1-a"]')
      line = REXML::XPath.first(transition, './/*[@class="transition-line"]')

      expect(REXML::XPath.first(transition, './title').text).to eq('Hot path')
      expect(line.attributes['style']).to include('stroke: #ef4444')
      expect(line.attributes['style']).to include('stroke-width: 3')
      expect(line.attributes['style']).to include('stroke-dasharray: 8 5')
    end

    it 'uses transition metadata URL as an SVG link' do
      local = described_class.new
      local.add_state('q0')
      local.add_state('q1')
      local.add_transition('q0', 'q1', 'docs', metadata: { url: 'https://example.com/edge' })

      svg_output = local.to_svg
      doc = REXML::Document.new(svg_output)
      link = REXML::XPath.first(doc, '//g[@id="transition-q0-q1-docs"]/a')

      expect(link.attributes['href']).to eq('https://example.com/edge')
      expect(REXML::XPath.first(link, './/*[@class="transition-line"]')).not_to be_nil
    end

    it 'can highlight selected transitions and fade inactive transitions' do
      svg_output = automaton.to_svg(highlight_transitions: [{ from: 'q0', to: 'q1', label: 'a' }])
      doc = REXML::Document.new(svg_output)
      highlighted = REXML::XPath.first(doc, '//g[@id="transition-q0-q1-a"]')
      inactive = REXML::XPath.first(doc, '//g[@id="transition-q1-q2-b"]')

      expect(highlighted.attributes['class']).to include('highlighted-transition')
      expect(inactive.attributes['class']).to include('inactive-transition')
    end

    it 'applies custom themes' do
      svg_output = automaton.to_svg(theme: :ocean)
      doc = REXML::Document.new(svg_output)
      style = REXML::XPath.first(doc, '//style')
      background = REXML::XPath.first(doc, '//rect[@class="diagram-background"]')

      expect(style.text).to include('stroke: #0369a1')
      expect(background).not_to be_nil
    end

    it 'supports accessibility focused named themes' do
      high_contrast = automaton.to_svg(theme: :high_contrast)
      color_blind = automaton.to_svg(theme: :color_blind)

      expect(high_contrast).to include('#ffff00')
      expect(color_blind).to include('#0072b2')
    end

    it 'supports print named theme' do
      svg_output = automaton.to_svg(theme: :print)

      expect(svg_output).to include('#ffffff')
      expect(svg_output).to include('stroke: #000000')
    end

    it 'supports style preset named themes' do
      minimal = automaton.to_svg(theme: :minimal)
      academic = automaton.to_svg(theme: :academic)
      presentation = automaton.to_svg(theme: :presentation)

      expect(minimal).to include('#111827')
      expect(academic).to include('#1e3a8a')
      expect(presentation).to include('#38bdf8')
    end

    it 'supports optional SVG state effects' do
      svg_output = automaton.to_svg(state_effect: :shadow)
      doc = REXML::Document.new(svg_output)
      style = REXML::XPath.first(doc, '//style')

      expect(style.text).to include('filter: drop-shadow')
    end

    it 'supports automatic dark mode with prefers-color-scheme' do
      svg_output = automaton.to_svg(theme: :auto)
      doc = REXML::Document.new(svg_output)
      style = REXML::XPath.first(doc, '//style')

      expect(style.text).to include('@media (prefers-color-scheme: dark)')
      expect(style.text).to include('--graphomaton-background: #111827')
      expect(style.text).to include('var(--graphomaton-state-fill')
    end

    it 'creates circles for each state' do
      svg_output = automaton.to_svg
      doc = REXML::Document.new(svg_output)
      circles = REXML::XPath.match(doc, '//circle[@class="state-circle" or @class="state-circle final-state"]')
      expect(circles.size).to be >= 3
    end

    it 'uses state display labels and styles in SVG output' do
      local = described_class.new
      local.add_state('q0', label: 'Start State', style: { fill: '#fee2e2', stroke: '#dc2626' })

      svg_output = local.to_svg
      doc = REXML::Document.new(svg_output)
      circle = REXML::XPath.first(doc, '//g[@id="state-q0"]/circle')

      expect(svg_output).to include('Start State')
      expect(circle.attributes['style']).to include('fill: #fee2e2')
      expect(circle.attributes['style']).to include('stroke: #dc2626')
    end

    it 'uses state metadata as SVG tooltip' do
      local = described_class.new
      local.add_state('q0', metadata: { tooltip: 'Entry point' })

      svg_output = local.to_svg
      doc = REXML::Document.new(svg_output)
      title = REXML::XPath.first(doc, '//g[@id="state-q0"]/title')

      expect(title.text).to eq('Entry point')
    end

    it 'can use full labels as SVG tooltips' do
      local = described_class.new
      local.add_state('q0', label: 'A very long state label')
      local.add_state('q1')
      local.add_transition('q0', 'q1', 'a very long transition label')

      svg_output = local.to_svg(label_tooltips: true)
      doc = REXML::Document.new(svg_output)
      state_title = REXML::XPath.first(doc, '//g[@id="state-q0"]/title')
      transition_title = REXML::XPath.first(doc, '//g[@id="transition-q0-q1-a-very-long-transition-label"]/title')

      expect(state_title.text).to eq('A very long state label')
      expect(transition_title.text).to eq('a very long transition label')
    end

    it 'escapes XML special characters in SVG labels and metadata' do
      local = described_class.new
      local.add_state('q<0>', label: 'A&B "state"', metadata: { tooltip: 'Use <entry> & "quoted" text' })
      local.add_state('q1')
      local.add_transition('q<0>', 'q1', 'a < b & c > d')

      svg_output = local.to_svg(label_tooltips: true)
      doc = REXML::Document.new(svg_output)
      state = REXML::XPath.match(doc, '//g[@data-state]').find { |node| node.attributes['data-state'] == 'q<0>' }
      transition = REXML::XPath.match(doc, '//g[@data-label]').find { |node| node.attributes['data-label'] == 'a < b & c > d' }

      expect(state).not_to be_nil
      expect(transition).not_to be_nil
      expect(svg_output).to include('A&amp;B')
    end

    it 'uses state metadata URL as an SVG link' do
      local = described_class.new
      local.add_state('docs', metadata: { url: 'https://example.com/docs', tooltip: 'Docs' })

      svg_output = local.to_svg
      doc = REXML::Document.new(svg_output)
      link = REXML::XPath.first(doc, '//g[@id="state-docs"]/a')

      expect(link.attributes['href']).to eq('https://example.com/docs')
      expect(link.attributes['target']).to eq('_blank')
    end

    it 'supports global and per-state SVG shapes' do
      local = described_class.new
      local.add_state('q0')
      local.add_state('q1', shape: :rounded_rect)

      svg_output = local.to_svg(state_shape: :ellipse)
      doc = REXML::Document.new(svg_output)

      expect(REXML::XPath.first(doc, '//g[@id="state-q0"]/ellipse')).not_to be_nil
      expect(REXML::XPath.first(doc, '//g[@id="state-q1"]/rect')).not_to be_nil
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

    it 'supports initial arrow length and label options' do
      svg_output = automaton.to_svg(initial_arrow_length: 48, initial_arrow_label: 'entry')
      doc = REXML::Document.new(svg_output)
      initial_arrow = REXML::XPath.first(doc, '//line[@class="initial-arrow"]')
      label = REXML::XPath.match(doc, '//text[@class="transition-label"]').find { |node| node.text == 'entry' }

      expect(initial_arrow.attributes['x2'].to_f - initial_arrow.attributes['x1'].to_f).to eq(48.0)
      expect(label).not_to be_nil
    end

    it 'aligns initial arrows with the SVG direction' do
      svg_output = automaton.to_svg(direction: :tb)
      doc = REXML::Document.new(svg_output)
      initial_arrow = REXML::XPath.first(doc, '//line[@class="initial-arrow"]')

      expect(initial_arrow.attributes['y1'].to_f).to be < initial_arrow.attributes['y2'].to_f
      expect(initial_arrow.attributes['x1'].to_f).to eq(initial_arrow.attributes['x2'].to_f)
    end

    it 'can create final arrows' do
      svg_output = automaton.to_svg(show_final_arrows: true)
      doc = REXML::Document.new(svg_output)
      final_arrow = REXML::XPath.first(doc, '//line[@class="final-arrow"]')
      final_label = REXML::XPath.match(doc, '//text[@class="transition-label"]').find { |label| label.text == 'final' }

      expect(final_arrow).not_to be_nil
      expect(final_label).not_to be_nil
    end

    it 'supports final arrow length and label options' do
      svg_output = automaton.to_svg(show_final_arrows: true, final_arrow_length: 44, final_arrow_label: 'done')
      doc = REXML::Document.new(svg_output)
      final_arrow = REXML::XPath.first(doc, '//line[@class="final-arrow"]')
      label = REXML::XPath.match(doc, '//text[@class="transition-label"]').find { |node| node.text == 'done' }

      expect(final_arrow.attributes['x2'].to_f - final_arrow.attributes['x1'].to_f).to eq(44.0)
      expect(label).not_to be_nil
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

    it 'supports auto_size option' do
      svg_output = automaton.to_svg(100, 100, auto_size: true, node_spacing: 200)
      doc = REXML::Document.new(svg_output)
      svg = doc.root

      expect(svg.attributes['width'].to_f).to be > 100.0
      expect(svg.attributes['height'].to_f).to be > 100.0
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

    it 'can sort merged SVG transition labels' do
      local = described_class.new
      local.add_state('q0')
      local.add_state('q1')
      local.add_transition('q0', 'q1', 'b')
      local.add_transition('q0', 'q1', 'a')

      svg_output = local.to_svg(sort_labels: true)
      doc = REXML::Document.new(svg_output)
      labels = REXML::XPath.match(doc, '//text[@class="transition-label"]')

      expect(labels.map(&:text)).to include('a, b')
    end

    it 'can hide transition label backgrounds' do
      svg_output = automaton.to_svg(label_background: false)
      doc = REXML::Document.new(svg_output)

      expect(REXML::XPath.match(doc, '//rect[@class="label-bg"]')).to be_empty
      expect(REXML::XPath.match(doc, '//text[@class="transition-label"]')).not_to be_empty
    end

    it 'supports transition label padding, radius, and borders' do
      svg_output = automaton.to_svg(label_padding: 40, label_radius: 8, label_border: true)
      doc = REXML::Document.new(svg_output)
      style = REXML::XPath.first(doc, '//style')
      label_bg = REXML::XPath.first(doc, '//rect[@class="label-bg"]')

      expect(style.text).to include('stroke-width: 1')
      expect(label_bg.attributes['width'].to_f).to be > 80
      expect(label_bg.attributes['rx']).to eq('8.0')
    end

    it 'can highlight unreachable states' do
      automaton.add_state('q3')
      svg_output = automaton.to_svg(highlight_unreachable: true)
      doc = REXML::Document.new(svg_output)
      unreachable = REXML::XPath.first(doc, '//g[@id="state-q3"]')

      expect(unreachable.attributes['class']).to include('unreachable-state')
    end

    it 'can highlight dead and trap states' do
      local = described_class.new
      local.add_state('q0')
      local.add_state('accept')
      local.add_state('dead')
      local.add_state('trap')
      local.set_initial('q0')
      local.add_final('accept')
      local.add_transition('q0', 'accept', 'ok')
      local.add_transition('dead', 'trap', 'miss')
      local.add_transition('trap', 'trap', 'loop')

      svg_output = local.to_svg(highlight_dead_states: true)
      doc = REXML::Document.new(svg_output)
      dead = REXML::XPath.first(doc, '//g[@id="state-dead"]')
      trap = REXML::XPath.first(doc, '//g[@id="state-trap"]')
      style = REXML::XPath.first(doc, '//style')

      expect(dead.attributes['class']).to include('dead-state')
      expect(trap.attributes['class']).to include('trap-state')
      expect(style.text).to include('.dead-state')
    end

    it 'can highlight initial and accepting states' do
      svg_output = automaton.to_svg(highlight_initial_state: true, highlight_final_states: true)
      doc = REXML::Document.new(svg_output)
      initial = REXML::XPath.first(doc, '//g[@id="state-q0"]')
      final = REXML::XPath.first(doc, '//g[@id="state-q2"]')
      style = REXML::XPath.first(doc, '//style')

      expect(initial.attributes['class']).to include('initial-state')
      expect(final.attributes['class']).to include('accepting-state')
      expect(style.text).to include('.accepting-state')
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

    it 'renders many states without invalid SVG' do
      local = described_class.new
      50.times do |index|
        local.add_state("q#{index}")
        local.add_transition("q#{index - 1}", "q#{index}", index.to_s) if index.positive?
      end
      local.set_initial('q0')
      local.add_final('q49')

      svg_output = local.to_svg(1600, 1000, layout: :grid)

      expect { REXML::Document.new(svg_output) }.not_to raise_error
      expect(REXML::XPath.match(REXML::Document.new(svg_output), '//g[@data-state]').size).to eq(50)
    end

    it 'supports straight edge style' do
      local = described_class.new
      local.add_state('q0')
      local.add_state('q1')
      local.add_state('q2')
      local.add_transition('q0', 'q2', 'skip')

      svg_output = local.to_svg(edge_style: :straight)
      doc = REXML::Document.new(svg_output)

      expect(REXML::XPath.first(doc, '//line[@class="transition-line"]')).not_to be_nil
      expect(REXML::XPath.match(doc, '//path[@class="transition-line"]')).to be_empty
    end

    it 'supports orthogonal edge style' do
      local = described_class.new
      local.add_state('q0')
      local.add_state('q1')
      local.add_transition('q0', 'q1', 'step')

      svg_output = local.to_svg(edge_style: :orthogonal)
      doc = REXML::Document.new(svg_output)
      path = REXML::XPath.first(doc, '//path[@class="transition-line"]')

      expect(path.attributes['d']).to include(' L ')
    end

    it 'handles transitions between states at the same coordinate' do
      local = described_class.new
      local.add_state('q0', 200, 200)
      local.add_state('q1', 200, 200)
      local.add_transition('q0', 'q1', 'same point')

      svg_output = local.to_svg(layout: :manual)
      doc = REXML::Document.new(svg_output)
      path = REXML::XPath.first(doc, '//path[@class="transition-line"]')

      expect(path.attributes['d']).to include('C')
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

      it 'supports explicit self-loop placement' do
        svg_output = automaton.to_svg(loop_position: :right)
        doc = REXML::Document.new(svg_output)
        state = REXML::XPath.first(doc, '//g[@id="state-q1"]/circle')
        loop_label = REXML::XPath.match(doc, '//text[@class="transition-label"]').find { |label| label.text == 'loop' }

        expect(loop_label.attributes['x'].to_f).to be > state.attributes['cx'].to_f
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

    it 'can include the Mermaid source code in HTML output' do
      html_output = automaton.to_html(show_source: true)

      expect(html_output).to include('class="mermaid-source"')
      expect(html_output).to include('stateDiagram-v2')
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
      expect(png_exporter).to receive(:export).with(1000, 800, theme: :dark, scale: 1.0, converter: :auto).and_return(png_output)

      expect(automaton.to_png(1000, 800, theme: :dark)).to eq(png_output)
    end

    it 'supports scaled PNG export' do
      png_output = Graphomaton::Exporters::Png::PNG_SIGNATURE + 'png-data'.b
      png_exporter = instance_double(Graphomaton::Exporters::Png)

      expect(Graphomaton::Exporters::Png).to receive(:new).with(automaton).and_return(png_exporter)
      expect(png_exporter).to receive(:export).with(1000, 800, theme: :dark, scale: 2.0, converter: :auto).and_return(png_output)

      expect(automaton.to_png(1000, 800, theme: :dark, scale: 2.0)).to eq(png_output)
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
      allow(automaton).to receive(:to_png).with(1200, 900, theme: :forest, scale: 1.0, converter: :auto).and_return(png_output)

      automaton.save_png(temp_file, 1200, 900, theme: :forest)

      expect(File.binread(temp_file)).to eq(png_output)
    end
  end

  describe '#render and #save' do
    let(:temp_file) { 'test_output.render.dot' }
    let(:mermaid_file) { 'test_output.render.mmd' }

    after do
      FileUtils.rm_f(temp_file)
      FileUtils.rm_f(mermaid_file)
    end

    before do
      automaton.add_state('q0')
      automaton.add_state('q1')
      automaton.add_transition('q0', 'q1', 'a')
    end

    it 'renders SVG through the unified render API' do
      svg_output = automaton.render(format: :svg, width: 900, height: 700, layout: :grid)
      doc = REXML::Document.new(svg_output)

      expect(doc.root.attributes['width']).to eq('900')
      expect(doc.root.attributes['height']).to eq('700')
    end

    it 'renders text formats through the unified render API' do
      dot_output = automaton.render(format: :dot, direction: :tb)

      expect(dot_output).to include('rankdir=TB')
    end

    it 'saves by inferring format from filename extension' do
      automaton.save(temp_file, direction: :rl)

      expect(File.read(temp_file)).to include('rankdir=RL')
    end

    it 'supports common Mermaid filename extension aliases' do
      automaton.save(mermaid_file)

      expect(File.read(mermaid_file)).to include('stateDiagram-v2')
    end

    it 'rejects unknown render formats' do
      expect do
        automaton.render(format: :unknown)
      end.to raise_error(ArgumentError, /Unknown format/)
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
