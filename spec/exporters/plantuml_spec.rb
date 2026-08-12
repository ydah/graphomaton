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
        expect(plantuml_output).to end_with("@enduml\n")
      end

      it 'applies SVG theme colors when requested' do
        plantuml_output = described_class.new(automaton, theme: :ocean).export

        expect(plantuml_output).to include('skinparam backgroundColor #eff6ff')
        expect(plantuml_output).to include('BorderColor #0369a1')
        expect(plantuml_output).to include('ArrowFontColor #0284c7')
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

      it 'declares states that do not participate in transitions' do
        plantuml_output = plantuml_exporter.export

        expect(plantuml_output).to include('state "C" as C')
      end

      it 'uses explicit state labels when provided' do
        automaton.add_state('q_named', label: 'Named State')

        plantuml_output = plantuml_exporter.export

        expect(plantuml_output).to include('state "Named State" as q_named')
      end

      it 'can render state metadata as PlantUML notes' do
        automaton.add_state('q_note', metadata: { note: 'Entry state' })

        plantuml_output = described_class.new(automaton, notes: true).export

        expect(plantuml_output).to include('note right of q_note : Entry state')
      end

      it 'can render state metadata groups as PlantUML composite blocks' do
        automaton.add_state('grouped_a', metadata: { group: 'alpha' })
        automaton.add_state('grouped_b', label: 'Grouped B', metadata: { group: 'alpha' })

        plantuml_output = plantuml_exporter.export

        expect(plantuml_output).to match(/state "alpha" as group_\d+ \{/)
        expect(plantuml_output).to include('state "grouped_a" as grouped_a')
        expect(plantuml_output).to include('state "Grouped B" as grouped_b')
      end

      it 'can render PlantUML choice, fork, and join pseudostates from metadata' do
        automaton.add_state('decision', metadata: { plantuml: { shape: 'choice' } })
        automaton.add_state('split', metadata: { plantuml_shape: 'fork' })
        automaton.add_state('merge', metadata: { mermaid_type: 'join' })

        plantuml_output = plantuml_exporter.export

        expect(plantuml_output).to include('state decision <<choice>>')
        expect(plantuml_output).to include('state split <<fork>>')
        expect(plantuml_output).to include('state merge <<join>>')
      end

      it 'nests multi-level composite states as a tree' do
        local = Graphomaton.new
        local.add_state('workflow')
        local.add_state('review', metadata: { parent: 'workflow' })
        local.add_state('approved', metadata: { parent: 'review' })

        lines = described_class.new(local).export.lines
        workflow_block = lines.index { |line| line.match?(/^state workflow \{/) }
        review_block = lines.index { |line| line.match?(/^  state review \{/) }
        approved = lines.index { |line| line.match?(/^    state "approved" as approved/) }

        expect(workflow_block).to be < review_block
        expect(review_block).to be < approved
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

      it 'supports direction option' do
        plantuml_output = described_class.new(automaton, direction: :bt).export
        expect(plantuml_output).to include('bottom to top direction')
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
        expect(plantuml_output).to include('state "State 1" as state_1')
        expect(plantuml_output).to include('state "State-2" as state_2')
      end

      it 'handles special characters in labels' do
        plantuml_output = plantuml_exporter.export
        expect(plantuml_output).to include('a/b')
      end

      it 'escapes backslashes and newlines in labels' do
        automaton.add_transition('State 1', 'State-2', "a\\b\nc")

        plantuml_output = plantuml_exporter.export

        expect(plantuml_output).to include('a\\\\b\\nc')
      end

      it 'uniquifies colliding sanitized state names' do
        local = Graphomaton.new
        local.add_state('State 1')
        local.add_state('State-1')
        local.add_transition('State 1', 'State-1', 'a')
        local.add_transition('State-1', 'State 1', 'b')

        plantuml_output = described_class.new(local).export

        expect(plantuml_output).to include('state "State-1" as state_2')
        expect(plantuml_output).to include('state_1 --> state_2 : a')
        expect(plantuml_output).to include('state_2 --> state_1 : b')
      end

      it 'allocates safe IDs for reserved words, syntax characters, and leading digits' do
        local = Graphomaton.new
        ['state', '[*]', 'A:B', '123start'].each { |name| local.add_state(name) }

        plantuml_output = described_class.new(local).export

        expect(plantuml_output.scan(/as state_\d+/).size).to eq(4)
        expect(plantuml_output).to include('state "state" as state_1')
      end

      it 'preserves pseudostates inside groups' do
        local = Graphomaton.new
        local.add_state('decision', metadata: { group: 'flow', plantuml_type: 'choice' })

        plantuml_output = described_class.new(local).export

        expect(plantuml_output).to include('state "decision" as decision <<choice>>')
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
        expect(plantuml_output).to end_with("@enduml\n")

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
