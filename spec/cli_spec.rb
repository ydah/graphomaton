# frozen_string_literal: true

require 'open3'
require 'rbconfig'
require 'tmpdir'

RSpec.describe 'graphomaton CLI' do
  it 'renders a YAML automaton to SVG' do
    Dir.mktmpdir do |dir|
      input = File.join(dir, 'automaton.yml')
      output = File.join(dir, 'diagram.svg')
      File.write(
        input,
        <<~YAML
          states:
            - id: q0
              initial: true
            - id: q1
              final: true
          transitions:
            - from: q0
              to: q1
              label: a
        YAML
      )

      stdout, stderr, status = Open3.capture3(
        RbConfig.ruby,
        File.expand_path('../exe/graphomaton', __dir__),
        '--input',
        input,
        '--output',
        output
      )

      expect(status).to be_success, stderr
      expect(stdout).to eq('')
      expect(File.read(output)).to include('<svg')
    end
  end

  it 'fails for unsupported input extensions' do
    Dir.mktmpdir do |dir|
      input = File.join(dir, 'automaton.txt')
      output = File.join(dir, 'diagram.svg')
      File.write(input, '{}')

      _stdout, stderr, status = Open3.capture3(
        RbConfig.ruby,
        File.expand_path('../exe/graphomaton', __dir__),
        '--input',
        input,
        '--output',
        output
      )

      expect(status).not_to be_success
      expect(stderr).to include('Input file must use .json, .yml, or .yaml extension')
    end
  end
end
