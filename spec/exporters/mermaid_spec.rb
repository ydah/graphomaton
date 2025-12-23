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
      expect(html_output).to include('A --> B : test')
    end

    it 'includes mermaid initialization' do
      html_output = mermaid_exporter.export_html
      expect(html_output).to include('mermaid.initialize')
    end
  end
end
