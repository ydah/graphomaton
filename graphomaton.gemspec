# frozen_string_literal: true

require_relative 'lib/graphomaton/version'

Gem::Specification.new do |spec|
  spec.name = 'graphomaton'
  spec.version = Graphomaton::VERSION
  spec.authors = ['Yudai Takada']
  spec.email = ['t.yudai92@gmail.com']

  spec.summary = 'Generate and analyze finite state machine diagrams in multiple formats.'
  spec.description = 'Graphomaton creates, analyzes, lays out, and exports finite state machines as SVG, PNG, PDF, WebP, Mermaid.js, GraphViz DOT, PlantUML, and standalone HTML.'
  spec.homepage = 'https://github.com/ydah/graphomaton'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.2.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata['documentation_uri'] = spec.homepage
  spec.metadata['bug_tracker_uri'] = "#{spec.homepage}/issues"
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir.chdir(__dir__) do
    Dir['lib/**/*', 'exe/*', 'sig/**/*', 'README.md', 'CHANGELOG.md', 'LICENSE.txt']
      .select { |path| File.file?(path) }
      .sort
  end
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'rexml', '~> 3.4'
end
