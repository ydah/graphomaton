# frozen_string_literal: true

require 'graphomaton'
require 'rexml/document'

RSpec.describe 'SVG structural regression coverage' do
  it 'preserves key SVG structures for a feature-rich diagram' do
    automaton = Graphomaton.new
    automaton.add_state('q0', 100, 120, label: 'Start', metadata: { group: 'flow', icon: 'S', tooltip: 'Entry' })
    automaton.add_state('q1', 260, 120, label: 'Review', metadata: { group: 'flow' })
    automaton.add_state('q2', 420, 120, label: 'Done', metadata: { group: 'flow' })
    automaton.set_initial('q0')
    automaton.add_final('q2')
    automaton.add_transition('q0', 'q1', 'submit', metadata: { bundle: 'main', tooltip: 'Submit for review' })
    automaton.add_transition('q1', 'q2', 'approve', line_style: :dashed)
    automaton.add_transition('q1', 'q0', 'reject')

    doc = REXML::Document.new(
      automaton.to_svg(
        layout: :manual,
        label_tooltips: true,
        html_tooltips: true,
        rotate_labels: true,
        scc_groups: true,
        show_final_arrows: true
      )
    )

    expect(REXML::XPath.match(doc, '//g[@class="states"]/g[@data-state]').size).to eq(3)
    expect(REXML::XPath.match(doc, '//g[contains(@class, "transition")]').size).to be >= 3
    expect(REXML::XPath.match(doc, '//rect[@class="state-group-box"]').size).to be >= 1
    expect(REXML::XPath.match(doc, '//text[@class="state-icon"]').map(&:text)).to include('S')
    expect(REXML::XPath.first(doc, '//g[@data-bundle="main"]').attributes['class']).to include('bundled-transition')
    expect(REXML::XPath.first(doc, '//g[@id="state-q0"]').attributes['data-tooltip']).to eq('Entry')
    expect(REXML::XPath.first(doc, '//g[@class="final-transition"]')).not_to be_nil
  end
end
