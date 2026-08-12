# frozen_string_literal: true

require 'graphomaton'
require 'stringio'

RSpec.describe 'Graphomaton model API' do
  it 'stores immutable value objects behind read-only compatibility snapshots' do
    graph = Graphomaton.new
    graph.add_state('q0', metadata: { tags: ['start'] })
    graph.add_transition('q0', 'q0', 'loop')

    expect(graph.state_records.fetch('q0')).to be_a(Graphomaton::State)
    expect(graph.transition_records.first).to be_a(Graphomaton::Transition)
    expect(graph.states).to be_frozen
    expect(graph.states.fetch('q0')).to be_frozen
    expect(graph.transitions).to be_frozen
    expect { graph.states.delete('q0') }.to raise_error(FrozenError)
    expect { graph.states['q0'][:metadata][:tags] << 'changed' }.to raise_error(FrozenError)
  end

  it 'copies and freezes every mutable value-object field at the model boundary' do
    label_text = +'go'
    guard_text = +'ready?'
    shape = +'diamond'
    line_style = +'dashed'
    label = Graphomaton::Label.uml(event: label_text, guard: guard_text)
    options = { labels: { wrap: true }, title: +'Diagram' }
    render_options = Graphomaton::RenderOptions.new(options: options)
    diagnostic_path = ['states', +'q0']
    diagnostic = Graphomaton::Diagnostic.new(
      code: 'example', severity: :warning, path: diagnostic_path, message: 'Example', hint: nil
    )
    render_result = Graphomaton::RenderResult.new(
      output: +'output', diagnostics: [diagnostic], bounds: { width: 1 }, layout: { 'q0' => { x: 1 } }
    )

    graph = Graphomaton.new
    graph.add_state('q0', shape: shape)
    graph.add_transition('q0', 'q0', label, line_style: line_style)
    label_text << '-changed'
    guard_text << '-changed'
    shape << '-changed'
    line_style << '-changed'
    options[:title] << '-changed'

    stored_label = graph.transition_records.first.label
    expect(stored_label.to_s).to eq('go [ready?]')
    expect(graph.state_records.fetch('q0').shape).to eq('diamond')
    expect(graph.transition_records.first.line_style).to eq('dashed')
    expect(render_options.options[:title]).to eq('Diagram')
    expect { stored_label.value[:event] << '-changed' }.to raise_error(FrozenError)
    expect { render_options.options[:labels][:wrap] = false }.to raise_error(FrozenError)
    expect { diagnostic.path.last << '-changed' }.to raise_error(FrozenError)
    expect { render_result.layout['q0'][:x] = 2 }.to raise_error(FrozenError)
  end

  it 'supports explicit update and removal operations with revision tracking' do
    graph = Graphomaton.new
    expect(graph.revision).to eq(0)
    expect(graph.add_state('q0')).to equal(graph)
    expect(graph.add_state('q1')).to equal(graph)
    expect(graph.add_transition('q0', 'q1', 'go')).to equal(graph)
    transition_id = graph.transition_records.first.id
    revision = graph.revision

    graph.update_state('q0', label: 'Start')
    graph.update_transition(transition_id, label: 'next')
    graph.set_initial('q0').add_final('q1')

    expect(graph.revision).to eq(revision + 4)
    expect(graph.states['q0'][:label]).to eq('Start')
    expect(graph.transitions.first[:label]).to eq('next')
    expect { graph.remove_state('q0') }.to raise_error(ArgumentError, /cascade/)
    expect(graph.remove_state('q0', cascade: true)).to equal(graph)
    expect(graph.transitions).to be_empty
    expect(graph.initial_state).to be_nil
    expect(graph.remove_final('q1').clear_initial).to equal(graph)
  end

  it 'preserves coordinates on partial upserts and ignores effective no-op updates' do
    graph = Graphomaton.new
    graph.add_state('q0', 25, 40, label: 'Start')
    graph.add_transition('q0', 'q0', 'stay')
    graph.set_initial('q0')
    revision = graph.revision

    graph.upsert_state('q0', label: 'Updated')
    state = graph.state_records.fetch('q0')
    expect([state.x, state.y, state.label]).to eq([25, 40, 'Updated'])
    changed_revision = graph.revision
    expect(changed_revision).to eq(revision + 1)

    graph.update_state('q0', label: 'Updated')
    graph.update_transition(graph.transition_records.first.id)
    graph.set_initial('q0')
    expect(graph.revision).to eq(changed_revision)
    expect { graph.upsert_state('q0', 50, label: 'invalid') }
      .to raise_error(ArgumentError, /coordinates require both/)
  end

  it 'provides strict and deferred construction modes' do
    deferred = Graphomaton.new(validation: :deferred)
    expect { deferred.add_transition('q0', 'q1', 'go') }.not_to raise_error
    expect(deferred).not_to be_valid

    strict = Graphomaton.new(validation: :strict)
    expect { strict.add_transition('q0', 'q1', 'go') }
      .to raise_error(Graphomaton::ValidationError, /source.*not defined/)
  end

  it 'round trips the versioned canonical schema' do
    graph = Graphomaton.new
    graph.add_state('q0', label: Graphomaton::Label.text('Start'))
    graph.add_state('q1', kind: :join)
    graph.set_initial('q0').add_final('q1')
    graph.add_transition('q0', 'q1', Graphomaton::Label.uml(event: 'go', guard: 'ready?', action: 'start'))

    expect(Graphomaton.from_hash(graph.to_h)).to eq(graph)
    expect(Graphomaton.from_json(graph.to_json)).to eq(graph)
    expect(Graphomaton.from_yaml(graph.to_yaml)).to eq(graph)
    expect(graph.to_h[:version]).to eq(1)
    expect(graph.state_records.fetch('q0').label).to eq('Start')
    expect(graph.state_records.fetch('q1').kind).to eq(:join)
  end

  it 'exposes structured diagnostics and validation profiles' do
    graph = Graphomaton.new
    graph.add_state('q0')
    graph.add_state('q1')
    graph.add_transition('q0', 'q1', 'a')
    graph.add_transition('q0', 'q0', 'a')

    semantic = graph.validation_diagnostics(profile: :fsm_semantics)
    dfa = graph.validation_diagnostics(profile: :dfa)

    expect(semantic.map(&:code)).to contain_exactly('missing-initial-state', 'missing-final-state')
    expect(dfa.map(&:code)).to include('nondeterministic-transition')
    expect(semantic.first.to_h).to include(:code, :severity, :path, :message)
    expect { graph.validation_diagnostics(profile: :unknown) }
      .to raise_error(ArgumentError, /Unknown validation profiles: unknown/)
  end

  it 'validates structured symbol and epsilon labels with DFA semantics' do
    graph = Graphomaton.new
    %w[q0 q1 q2].each { |state| graph.add_state(state) }
    graph.set_initial('q0').add_final('q2')
    graph.add_transition('q0', 'q1', %w[a b])
    graph.add_transition('q0', 'q2', 'a')
    graph.add_transition('q1', 'q2', :epsilon)

    diagnostics = graph.validation_diagnostics(profile: :dfa)

    expect(diagnostics.map(&:code)).to include('nondeterministic-transition', 'epsilon-transition-in-dfa')
    expect(diagnostics.map(&:message)).to include(/label "a"/)
  end

  it 'provides indexed graph analyses with explicit semantics' do
    graph = Graphomaton.new
    %w[a b c sink].each { |state| graph.add_state(state) }
    graph.set_initial('a').add_final('c')
    graph.add_transition('a', 'b', 'x')
    graph.add_transition('b', 'c', 'y')
    graph.add_transition('sink', 'sink', 'z')

    expect(graph.reachable_from('b')).to eq(%w[b c])
    expect(graph.graph_roots).to eq(['a'])
    expect(graph.weakly_connected_components.map(&:sort)).to contain_exactly(%w[a b c], ['sink'])
    expect(graph.self_loop_traps).to eq(['sink'])
    expect(graph.sink_states).to eq(['c'])
    expect(graph.bottom_sccs).to include(['c'], ['sink'])
    expect(graph.outgoing_by_state['a'].first[:to]).to eq('b')
    expect(graph.transitions_by_pair[%w[a b]].first[:label]).to eq('x')
  end

  it 'writes rendered output to IO and accepts render option objects' do
    graph = Graphomaton.new
    graph.add_state('q0')
    io = StringIO.new
    options = Graphomaton::RenderOptions.new(format: :dot, width: 10, height: 10)

    expect(graph.write(io, format: :dot)).to be > 0
    expect(io.string).to include('digraph')
    expect(graph.render_with(options)).to include('digraph')
  end

  it 'declares exporter capabilities and reports semantic loss' do
    graph = Graphomaton.new
    graph.add_state('q0', style: { fill: 'red' }, metadata: { url: 'https://example.com' })
    graph.add_state('q1')
    graph.add_transition('q0', 'q1', 'go', line_style: :dashed)

    expect(Graphomaton::EXPORTERS.resolve('.GV')).to eq(:dot)
    expect(Graphomaton::Exporters::Dot.new(graph).capabilities).to include(:url, :line_style)
    expect(graph.semantic_diagnostics(:dot).map(&:message)).to include(/does not preserve state_style/)
    expect { graph.render(format: :dot, strict_semantics: true) }
      .to raise_error(Graphomaton::ExportError, /state_style/)
  end

  it 'renders exporter classes registered by applications' do
    exporter_class = Class.new do
      def initialize(graph)
        @graph = graph
      end

      def export(width, height, prefix:)
        "#{prefix}:#{@graph.state_records.size}:#{width}x#{height}"
      end
    end

    begin
      Graphomaton.register_exporter(
        :test_custom,
        aliases: %i[test_alias],
        extensions: %w[test-output],
        binary: true,
        exporter: exporter_class
      )

      graph = Graphomaton.new.add_state('q0').add_state('decision', kind: :choice)
      expect(graph.render(format: '.TEST-OUTPUT', width: 320, height: 240, prefix: 'ok')).to eq('ok:2:320x240')
      output = StringIO.new
      graph.write(output, format: :test_custom, width: 320, height: 240, prefix: 'ok')
      expect(output.external_encoding).to eq(Encoding::ASCII_8BIT)
      expect(graph.semantic_diagnostics(:test_custom).map(&:message)).to include(/does not preserve pseudostate/)
      expect { graph.render(format: :test_custom, strict_semantics: true, prefix: 'ok') }
        .to raise_error(Graphomaton::ExportError, /pseudostate/)
      expect(Graphomaton::EXPORTERS.resolve(:test_alias)).to eq(:test_custom)
      expect do
        Graphomaton.register_exporter(:another_custom, aliases: %i[test_alias], exporter: exporter_class)
      end.to raise_error(ArgumentError, /already registered/)
    ensure
      Graphomaton::EXPORTERS.unregister(:test_custom) if Graphomaton::EXPORTERS.formats.include?(:test_custom)
    end
  end

  it 'keeps low-level layout algorithms private' do
    graph = Graphomaton.new

    expect(graph).not_to respond_to(:layout_force_positions)
    expect(graph).to respond_to(:layout_positions)
  end
end
