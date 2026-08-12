# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)

desc 'Validate RBS signatures'
task :rbs do
  sh 'bundle exec rbs -I sig validate'
end

desc 'Build the packaged gem'
task :package_smoke do
  sh 'gem build graphomaton.gemspec --output /tmp/graphomaton-package-smoke.gem'
end

task default: %i[spec rbs]
