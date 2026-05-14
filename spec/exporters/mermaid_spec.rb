# frozen_string_literal: true

require 'graphomaton'

RSpec.describe Graphomaton::Exporters::Mermaid do
  let(:automaton) { Graphomaton.new }
  let(:mermaid_exporter) { described_class.new(automaton) }

  describe '#export' do
    context 'with empty automaton' do
      it 'generates valid Mermaid syntax' do
        mermaid_output = mermaid_exporter.export
        expect(mermaid_output).to include('stateDiagram-v2')
      end
    end

    context 'with states' do
      before do
        automaton.add_state('A')
        automaton.add_state('B')
        automaton.add_state('C')
        automaton.add_transition('A', 'B', 'x')
      end

      it 'includes all states in transitions' do
        mermaid_output = mermaid_exporter.export
        expect(mermaid_output).to include('A')
        expect(mermaid_output).to include('B')
      end

      it 'uses explicit state labels when provided' do
        automaton.add_state('q_named', label: 'Named State')

        mermaid_output = mermaid_exporter.export

        expect(mermaid_output).to include('state "Named State" as q_named')
      end

      it 'can render state metadata as Mermaid notes' do
        automaton.add_state('q_note', metadata: { note: 'Entry state' })

        mermaid_output = described_class.new(automaton, notes: true).export

        expect(mermaid_output).to include('note right of q_note: Entry state')
      end

      it 'can render Mermaid choice, fork, and join pseudostates from metadata' do
        automaton.add_state('decision', metadata: { mermaid: { shape: 'choice' } })
        automaton.add_state('split', metadata: { mermaid_shape: 'fork' })
        automaton.add_state('merge', metadata: { mermaid_type: 'join' })

        mermaid_output = mermaid_exporter.export

        expect(mermaid_output).to include('state decision <<choice>>')
        expect(mermaid_output).to include('state split <<fork>>')
        expect(mermaid_output).to include('state merge <<join>>')
      end

      it 'can emit Mermaid class definitions for state roles' do
        automaton.set_initial('A')
        automaton.add_final('C')

        mermaid_output = described_class.new(automaton, class_defs: true).export

        expect(mermaid_output).to include('classDef initial')
        expect(mermaid_output).to include('class A initial;')
        expect(mermaid_output).to include('class C final;')
      end

      it 'marks final states' do
        automaton.add_final('C')
        mermaid_output = mermaid_exporter.export
        expect(mermaid_output).to match(/C\s+-->\s+\[\*\]/)
      end
    end

    context 'with initial state' do
      before do
        automaton.add_state('Start')
        automaton.set_initial('Start')
      end

      it 'marks initial state with arrow from start' do
        mermaid_output = mermaid_exporter.export
        expect(mermaid_output).to include('[*] --> Start')
      end

      it 'accepts direction option' do
        mermaid_output = described_class.new(automaton, direction: :tb).export
        expect(mermaid_output).to include('direction TB')
      end
    end

    context 'with transitions' do
      before do
        automaton.add_state('A')
        automaton.add_state('B')
        automaton.add_state('C')
        automaton.add_transition('A', 'B', 'input_a')
        automaton.add_transition('B', 'C', 'input_b')
      end

      it 'includes all transitions with labels' do
        mermaid_output = mermaid_exporter.export
        expect(mermaid_output).to match(/A\s+-->\s+B\s*:\s*input_a/)
        expect(mermaid_output).to match(/B\s+-->\s+C\s*:\s*input_b/)
      end

      it 'handles self-loops' do
        automaton.add_transition('B', 'B', 'loop')
        mermaid_output = mermaid_exporter.export
        expect(mermaid_output).to match(/B\s+-->\s+B\s*:\s*loop/)
      end
    end

    context 'with special characters' do
      before do
        automaton.add_state('State 1')
        automaton.add_state('State-2')
        automaton.add_transition('State 1', 'State-2', 'a/b')
      end

      it 'handles spaces in state names' do
        mermaid_output = mermaid_exporter.export
        expect(mermaid_output).to include('State_1')
        expect(mermaid_output).to include('State_2')
      end

      it 'handles special characters in labels' do
        mermaid_output = mermaid_exporter.export
        expect(mermaid_output).to include('a/b')
      end

      it 'formats newlines in labels for Mermaid' do
        automaton.add_transition('State 1', 'State-2', "a\nb")

        mermaid_output = mermaid_exporter.export

        expect(mermaid_output).to include('a<br/>b')
      end

      it 'uniquifies colliding sanitized state names' do
        local = Graphomaton.new
        local.add_state('State 1')
        local.add_state('State-1')
        local.add_transition('State 1', 'State-1', 'a')
        local.add_transition('State-1', 'State 1', 'b')

        mermaid_output = described_class.new(local).export

        expect(mermaid_output).to include('state "State-1" as State_1_2')
        expect(mermaid_output).to include('State_1 --> State_1_2 : a')
        expect(mermaid_output).to include('State_1_2 --> State_1 : b')
      end
    end

    context 'with complete automaton' do
      before do
        automaton.add_state('q0')
        automaton.add_state('q1')
        automaton.add_state('q2')
        automaton.set_initial('q0')
        automaton.add_final('q2')
        automaton.add_transition('q0', 'q1', 'a')
        automaton.add_transition('q1', 'q2', 'b')
        automaton.add_transition('q2', 'q0', 'c')
      end

      it 'generates complete valid Mermaid diagram' do
        mermaid_output = mermaid_exporter.export

        # Should start with stateDiagram-v2
        expect(mermaid_output).to start_with('stateDiagram-v2')

        # Should have initial state marker
        expect(mermaid_output).to include('[*] --> q0')

        # Should have final state marker
        expect(mermaid_output).to match(/q2\s+-->\s+\[.*\*.*\]/)

        # Should have all transitions
        expect(mermaid_output).to match(/q0\s+-->\s+q1\s*:\s*a/)
        expect(mermaid_output).to match(/q1\s+-->\s+q2\s*:\s*b/)
        expect(mermaid_output).to match(/q2\s+-->\s+q0\s*:\s*c/)
      end
    end
  end

  describe '#export_html' do
    before do
      automaton.add_state('A')
      automaton.add_state('B')
      automaton.add_transition('A', 'B', 'test')
    end

    it 'generates valid HTML with Mermaid.js' do
      html_output = mermaid_exporter.export_html
      expect(html_output).to include('<!DOCTYPE html>')
      expect(html_output).to include('<html')
      expect(html_output).to include('</html>')
    end

    it 'includes Mermaid.js CDN link' do
      html_output = mermaid_exporter.export_html
      expect(html_output).to include('mermaid')
      expect(html_output).to include('cdn.jsdelivr.net')
    end

    it 'includes the diagram code' do
      html_output = mermaid_exporter.export_html
      expect(html_output).to include('stateDiagram-v2')
      expect(html_output).to include('A --&gt; B : test')
    end

    it 'escapes diagram code in HTML output' do
      automaton.add_transition('A', 'B', '<tag>&value')

      html_output = mermaid_exporter.export_html

      expect(html_output).to include('&lt;tag&gt;&amp;value')
    end

    it 'includes mermaid initialization' do
      html_output = mermaid_exporter.export_html
      expect(html_output).to include('mermaid.initialize')
    end

    it 'supports custom theme in HTML output' do
      html_output = mermaid_exporter.export_html(theme: :forest)
      expect(html_output).to include("theme: 'forest'")
    end

    it 'supports automatic dark mode theme in HTML output' do
      html_output = mermaid_exporter.export_html(theme: :auto)

      expect(html_output).to include("prefers-color-scheme: dark")
      expect(html_output).to include("? 'dark' : 'default'")
    end

    it 'supports offline script source override' do
      html_output = mermaid_exporter.export_html(offline: true, cdn: '/assets/mermaid.min.js')
      expect(html_output).to include('<script src="/assets/mermaid.min.js"></script>')
    end

    it 'supports custom page title and language' do
      html_output = mermaid_exporter.export_html(title: 'Automaton Viewer', lang: 'en')
      expect(html_output).to include('<title>Automaton Viewer</title>')
      expect(html_output).to include('<html lang="en">')
    end
  end
end
