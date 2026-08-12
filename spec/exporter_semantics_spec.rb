# frozen_string_literal: true

require 'graphomaton'
require 'rexml/document'

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

    expect([dot, mermaid, plantuml]).to all(end_with("\n"))

    expect(dot).to include('"__start__" -> "q0"')
    expect(mermaid).to include('[*] --> q0')
    expect(plantuml).to include('[*] --> q0')

    expect(dot).to include('"q2" [shape="doublecircle", label="Accept"]')
    expect(mermaid).to match(/q2\s+-->\s+\[\*\]/)
    expect(plantuml).to match(/q2\s+-->\s+\[\*\]/)

    expect(dot).to include('"q0" [label="Start"];')
    expect(mermaid).to include('state "Start" as q0')
    expect(plantuml).to include('state "Start" as q0')

    expect(dot).to include('"q0" -> "q1" [label="a"];')
    expect(mermaid).to include('q0 --> q1 : a')
    expect(plantuml).to include('q0 --> q1 : a')
  end

  it 'uses format-independent pseudostate kinds across exporters' do
    automaton.add_state('decision', kind: :choice)

    expect(automaton.to_dot).to include('"decision" [shape="diamond"]')
    expect(automaton.to_mermaid).to include('state decision <<choice>>')
    expect(automaton.to_plantuml).to include('state decision <<choice>>')

    svg = REXML::Document.new(automaton.to_svg)
    expect(REXML::XPath.first(svg, '//*[@data-state="decision"]/polygon')).not_to be_nil
  end

  it 'keeps carriage returns inside labels from becoming renderer directives' do
    graph = Graphomaton.new
    graph.add_state('q0', label: "Start\r@enduml")
    graph.add_state('q1')
    graph.add_transition('q0', 'q1', "go\rstate injected")

    outputs = [graph.to_dot, graph.to_mermaid, graph.to_plantuml]

    expect(outputs).to all(satisfy { |output| !output.include?("\r") })
    expect(outputs[0]).to include('Start\\n@enduml', 'go\\nstate injected')
    expect(outputs[1]).to include('Start<br/>@enduml', 'go<br/>state injected')
    expect(outputs[2]).to include('Start\\n@enduml', 'go\\nstate injected')
    expect(outputs[2].scan(/^@enduml$/).size).to eq(1)
  end
end
