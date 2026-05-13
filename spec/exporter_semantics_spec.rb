# frozen_string_literal: true

require 'graphomaton'

RSpec.describe 'exporter semantic consistency' do
  let(:automaton) do
    Graphomaton.new.tap do |graph|
      graph.add_state('q0', label: 'Start')
      graph.add_state('q1')
      graph.add_state('q2', label: 'Accept')
      graph.set_initial('q0')
      graph.add_final('q2')
      graph.add_transition('q0', 'q1', 'a')
      graph.add_transition('q1', 'q2', 'b')
    end
  end

  it 'keeps initial, final, labels, and transitions consistent across textual exporters' do
    dot = Graphomaton::Exporters::Dot.new(automaton).export
    mermaid = Graphomaton::Exporters::Mermaid.new(automaton).export
    plantuml = Graphomaton::Exporters::Plantuml.new(automaton).export

    expect(dot).to include('__start__ -> "q0"')
    expect(mermaid).to include('[*] --> q0')
    expect(plantuml).to include('[*] --> q0')

    expect(dot).to match(/node\s+\[shape\s+=\s+doublecircle\];\s+"q2"/)
    expect(mermaid).to match(/q2\s+-->\s+\[\*\]/)
    expect(plantuml).to match(/q2\s+-->\s+\[\*\]/)

    expect(dot).to include('"q0" [label="Start"];')
    expect(mermaid).to include('state "Start" as q0')
    expect(plantuml).to include('state "Start" as q0')

    expect(dot).to include('"q0" -> "q1" [label="a"];')
    expect(mermaid).to include('q0 --> q1 : a')
    expect(plantuml).to include('q0 --> q1 : a')
  end
end
