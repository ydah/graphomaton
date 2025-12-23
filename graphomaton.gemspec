# frozen_string_literal: true

require_relative 'lib/graphomaton/version'

Gem::Specification.new do |spec|
  spec.name = 'graphomaton'
  spec.version = Graphomaton::VERSION
  spec.authors = ['Yudai Takada']
  spec.email = ['t.yudai92@gmail.com']

  spec.summary = 'A tiny Ruby library for generating finite state machine (automaton) diagrams.'
  spec.description = 'Graphomaton is a lightweight Ruby library for creating and visualizing finite state machines. It supports multiple output formats including SVG, Mermaid.js, GraphViz DOT, and PlantUML, making it easy to generate professional automaton diagrams.'
  spec.homepage = 'https://github.com/ydah/graphomaton'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.2.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata['rubygems_mfa_required'] = 'true'

  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore .github/])
    end
  end
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'rexml', '~> 3.4'
end
