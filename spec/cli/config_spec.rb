# frozen_string_literal: true

require 'graphomaton/cli'
require 'tmpdir'

RSpec.describe Graphomaton::CLI::Config do
  it 'rejects aliases and unknown options' do
    Dir.mktmpdir do |directory|
      aliases = File.join(directory, 'aliases.yml')
      unknown = File.join(directory, 'unknown.yml')
      File.write(aliases, "svg:\n  labels: &labels\n    wrap: true\n  another: *labels\n")
      File.write(unknown, "svg:\n  typo_layout: force\n")

      expect { described_class.load(aliases, format: :svg, required: true) }
        .to raise_error(ArgumentError, /Alias parsing was not enabled/)
      expect { described_class.load(unknown, format: :svg, required: true) }
        .to raise_error(ArgumentError, /Unknown config option keys: typo_layout/)
    end
  end

  it 'normalizes format-specific label settings' do
    Dir.mktmpdir do |directory|
      path = File.join(directory, 'config.yml')
      File.write(path, "width: 900\nsvg:\n  layout: layered\n  labels:\n    wrap: true\n")

      expect(described_class.load(path, format: :svg, required: true)).to include(
        width: 900,
        layout: :layered,
        wrap: true
      )
    end
  end
end
