# frozen_string_literal: true

require 'graphomaton'

RSpec.describe Graphomaton::Exporters::Dot do
  let(:automaton) { Graphomaton.new }
  let(:dot_exporter) { described_class.new(automaton) }

  describe '#export' do
    context 'with empty automaton' do
      it 'generates valid DOT syntax' do
        dot_output = dot_exporter.export
        expect(dot_output).to include('digraph')
        expect(dot_output).to include('rankdir=LR')
      end

      it 'includes basic graph attributes' do
        dot_output = dot_exporter.export
        expect(dot_output).to match(/node\s+\[shape\s+=\s+circle\]/)
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
        dot_output = dot_exporter.export
        expect(dot_output).to include('"A"')
        expect(dot_output).to include('"B"')
      end

      it 'marks final states with double circle' do
        automaton.add_final('C')
        dot_output = dot_exporter.export
        expect(dot_output).to match(/node\s+\[shape\s+=\s+doublecircle\];\s+"C"/)
      end
    end

    context 'with initial state' do
      before do
        automaton.add_state('Start')
        automaton.set_initial('Start')
      end

      it 'creates invisible initial node' do
        dot_output = dot_exporter.export
        expect(dot_output).to include('__start__')
        expect(dot_output).to match(/__start__\s+\[shape=point\]/)
      end

      it 'creates arrow from invisible node to initial state' do
        dot_output = dot_exporter.export
        expect(dot_output).to include('__start__ -> "Start"')
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

      it 'includes all transitions' do
        dot_output = dot_exporter.export
        expect(dot_output).to include('"A" -> "B"')
        expect(dot_output).to include('"B" -> "C"')
      end

      it 'includes transition labels' do
        dot_output = dot_exporter.export
        expect(dot_output).to match(/"A"\s+->\s+"B"\s+\[label="input_a"\]/)
        expect(dot_output).to match(/"B"\s+->\s+"C"\s+\[label="input_b"\]/)
      end

      it 'handles self-loops' do
        automaton.add_transition('B', 'B', 'loop')
        dot_output = dot_exporter.export
        expect(dot_output).to match(/"B"\s+->\s+"B"\s+\[label="loop"\]/)
      end
    end

    context 'with special characters in labels' do
      before do
        automaton.add_state('State 1')
        automaton.add_state('State-2')
        automaton.add_transition('State 1', 'State-2', 'a/b')
      end

      it 'handles spaces in state names' do
        dot_output = dot_exporter.export
        expect(dot_output).to include('"State 1"')
        expect(dot_output).to include('"State-2"')
      end

      it 'handles special characters in labels' do
        dot_output = dot_exporter.export
        expect(dot_output).to match(/label="a\/b"/)
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

      it 'generates complete valid DOT graph' do
        dot_output = dot_exporter.export

        # Should contain digraph wrapper
        expect(dot_output).to start_with('digraph')
        expect(dot_output).to end_with('}')

        # Should contain all states in transitions
        expect(dot_output).to include('"q0"')
        expect(dot_output).to include('"q1"')
        expect(dot_output).to include('"q2"')

        # Should mark final state
        expect(dot_output).to match(/node\s+\[shape\s+=\s+doublecircle\];\s+"q2"/)

        # Should have initial arrow
        expect(dot_output).to include('__start__ -> "q0"')

        # Should have all transitions
        expect(dot_output).to include('"q0" -> "q1"')
        expect(dot_output).to include('"q1" -> "q2"')
        expect(dot_output).to include('"q2" -> "q0"')
      end
    end
  end
end
