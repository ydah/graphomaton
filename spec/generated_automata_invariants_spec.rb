# frozen_string_literal: true

require 'graphomaton'
require 'rexml/document'

RSpec.describe 'generated automata invariants' do
  def generated_automaton(seed:, state_count:)
    random = Random.new(seed)
    automaton = Graphomaton.new
    states = Array.new(state_count) { |index| "q#{index}" }

    states.each_with_index do |state, index|
      automaton.add_state(
        state,
        label: "State #{index}",
        metadata: {
          group: index.even? ? 'even' : 'odd',
          icon: index.zero? ? 'S' : nil
        }.compact
      )
    end
    automaton.set_initial(states.first)
    automaton.add_final(states.last)

    states.each_cons(2).with_index do |(from, to), index|
      automaton.add_transition(from, to, "step #{index}", metadata: { bundle: 'main' })
    end
    state_count.times do |index|
      from = states[index]
      to = states[random.rand(state_count)]
      automaton.add_transition(from, to, "generated #{seed}-#{index}")
    end

    automaton
  end

  it 'renders generated valid automata across all textual and SVG exporters' do
    [[11, 3], [29, 6], [47, 9]].each do |seed, state_count|
      automaton = generated_automaton(seed: seed, state_count: state_count)

      expect { automaton.validate! }.not_to raise_error
      expect(REXML::Document.new(automaton.to_svg(edge_style: :auto, scc_groups: true)).root.name).to eq('svg')
      expect(automaton.to_mermaid).to include('stateDiagram-v2')
      expect(automaton.to_dot).to include('digraph finite_state_machine')
      expect(automaton.to_plantuml).to include('@startuml')
    end
  end

  it 'preserves randomly connected Unicode and syntax-heavy identifiers' do
    identifier_parts = ['状態', 'é', '👨‍👩‍👧‍👦', '[*]', 'state', 'A:B', 'group-alpha', '123start']

    10.times do |seed|
      random = Random.new(seed)
      automaton = Graphomaton.new
      states = 24.times.map { |index| "#{identifier_parts[index % identifier_parts.size]} #{seed}-#{index}" }
      states.each { |state| automaton.add_state(state, label: "Label <#{state}> & Ω") }
      automaton.set_initial(states.first)
      automaton.add_final(states.last)
      48.times do |index|
        automaton.add_transition(states.sample(random: random), states.sample(random: random), "event #{index} → λ")
      end

      document = REXML::Document.new(automaton.to_svg(merge_parallel_transitions: false))
      expect(REXML::XPath.match(document, '//g[@data-state]').size).to eq(states.size)
      expect(REXML::XPath.match(document, '//g[@data-from]').size).to eq(48)
      mermaid = automaton.to_mermaid
      dot = automaton.to_dot
      plantuml = automaton.to_plantuml
      expect(mermaid).to end_with("\n")
      expect(dot).to end_with("\n")
      expect(plantuml).to end_with("\n")
      states.each do |state|
        expect(mermaid).to include("Label <#{state}> & Ω")
        expect(plantuml).to include("Label <#{state}> & Ω")
      end
    end
  end
end
