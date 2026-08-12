# frozen_string_literal: true

require 'rubygems'

RSpec.describe 'graphomaton.gemspec' do
  subject(:specification) { Gem::Specification.load(File.expand_path('../graphomaton.gemspec', __dir__)) }

  it 'packages runtime files without development-only sources' do
    expect(specification.files).to include('exe/graphomaton', 'lib/graphomaton.rb', 'README.md', 'CHANGELOG.md', 'LICENSE.txt')
    expect(specification.files.grep(%r{\A(?:spec|sample|tmp|\.github)/})).to be_empty
    expect(specification.files).not_to include('Gemfile', 'graphomaton.gemspec')
  end

  it 'publishes documentation and issue tracker metadata' do
    expect(specification.metadata).to include(
      'documentation_uri' => 'https://github.com/ydah/graphomaton',
      'bug_tracker_uri' => 'https://github.com/ydah/graphomaton/issues'
    )
  end
end
