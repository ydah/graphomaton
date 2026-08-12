# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))
require 'graphomaton'

counts = ARGV.empty? ? [100, 1_000, 10_000] : ARGV.map { |value| Integer(value, 10) }

puts "transitions\tseconds\tbytes"
counts.each do |count|
  automaton = Graphomaton.new
  automaton.add_state('source', 100, 100)
  automaton.add_state('target', 700, 500)
  count.times { |index| automaton.add_transition('source', 'target', "event-#{index}") }

  started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  output = automaton.to_svg(800, 600, layout: :manual, merge_parallel_transitions: false)
  elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at
  puts [count, format('%.3f', elapsed), output.bytesize].join("\t")
end
