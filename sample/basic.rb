# frozen_string_literal: true

require_relative '../lib/graphomaton'

automaton = Graphomaton.new

automaton.add_state('待機中')
automaton.add_state('お金投入済み')
automaton.add_state('商品選択済み')

automaton.set_initial('待機中')
automaton.add_final('待機中')

automaton.add_transition('待機中', 'お金投入済み', 'お金を投入する')
automaton.add_transition('お金投入済み', '商品選択済み', '商品のボタンを押す')
automaton.add_transition('商品選択済み', '待機中', '商品を排出する')

automaton.save_svg('automaton.svg')
puts 'Generated automaton.svg'

automaton.save_html('automaton.html')
puts 'Generated automaton.html (Mermaid.js - requires internet connection)'

automaton.save_dot('automaton.dot')
puts 'Generated automaton.dot (GraphViz format)'
puts 'To convert to PNG: dot -Tpng automaton.dot -o automaton.png'

automaton.save_plantuml('automaton.puml')
puts 'Generated automaton.puml (PlantUML format)'
puts 'To convert to PNG: Use PlantUML server or jar file'
