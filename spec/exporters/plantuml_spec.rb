# frozen_string_literal: true

require 'graphomaton'

RSpec.describe Graphomaton::Exporters::Plantuml do
  let(:automaton) { Graphomaton.new }
  let(:plantuml_exporter) { described_class.new(automaton) }

  describe '#export' do
    context 'with empty automaton' do
      it 'generates valid PlantUML syntax' do
        plantuml_output = plantuml_exporter.export
        expect(plantuml_output).to start_with('@startuml')
        expect(plantuml_output).to end_with('@enduml')
      end
    end

    context 'with states' do
      before do
        automaton.add_state('A')
        automaton.add_state('B')
        automaton.add_state('C')
        automaton.add_transition('A', 'B', 'x')
      end

      it 'includes states in transitions' do
        plantuml_output = plantuml_exporter.export
        expect(plantuml_output).to include('A')
        expect(plantuml_output).to include('B')
      end

      it 'marks final states' do
        automaton.add_final('C')
        plantuml_output = plantuml_exporter.export
        expect(plantuml_output).to match(/C\s+-->\s+\[\*\]/)
      end
    end

    context 'with initial state' do
      before do
        automaton.add_state('Start')
        automaton.set_initial('Start')
      end

      it 'marks initial state with arrow from start' do
        plantuml_output = plantuml_exporter.export
        expect(plantuml_output).to include('[*] --> Start')
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
        plantuml_output = plantuml_exporter.export
        expect(plantuml_output).to match(/A\s+-->\s+B\s*:\s*input_a/)
        expect(plantuml_output).to match(/B\s+-->\s+C\s*:\s*input_b/)
      end

      it 'handles self-loops' do
        automaton.add_transition('B', 'B', 'loop')
        plantuml_output = plantuml_exporter.export
        expect(plantuml_output).to match(/B\s+-->\s+B\s*:\s*loop/)
      end
    end

    context 'with special characters' do
      before do
        automaton.add_state('State 1')
        automaton.add_state('State-2')
        automaton.add_transition('State 1', 'State-2', 'a/b')
      end

      it 'handles spaces in state names' do
        plantuml_output = plantuml_exporter.export
        expect(plantuml_output).to include('State_1')
        expect(plantuml_output).to include('State_2')
      end

      it 'handles special characters in labels' do
        plantuml_output = plantuml_exporter.export
        expect(plantuml_output).to include('a/b')
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

      it 'generates complete valid PlantUML diagram' do
        plantuml_output = plantuml_exporter.export

        # Should be wrapped in @startuml/@enduml
        expect(plantuml_output).to start_with('@startuml')
        expect(plantuml_output).to end_with('@enduml')

        # Should have initial state marker
        expect(plantuml_output).to include('[*] --> q0')

        # Should have final state marker
        expect(plantuml_output).to match(/q2\s+-->\s+\[\*\]/)

        # Should have states in transitions
        expect(plantuml_output).to include('q0')
        expect(plantuml_output).to include('q1')
        expect(plantuml_output).to include('q2')

        # Should have all transitions
        expect(plantuml_output).to match(/q0\s+-->\s+q1\s*:\s*a/)
        expect(plantuml_output).to match(/q1\s+-->\s+q2\s*:\s*b/)
        expect(plantuml_output).to match(/q2\s+-->\s+q0\s*:\s*c/)
      end
    end

    context 'with non-ASCII characters' do
      before do
        automaton.add_state('状態A')
        automaton.add_state('状態B')
        automaton.add_transition('状態A', '状態B', '遷移')
      end

      it 'handles Japanese characters correctly' do
        plantuml_output = plantuml_exporter.export
        expect(plantuml_output).to include('状態A')
        expect(plantuml_output).to include('状態B')
        expect(plantuml_output).to include('遷移')
      end
    end
  end
end
