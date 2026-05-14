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

  it 'renders with a YAML theme file' do
    Dir.mktmpdir do |dir|
      input = File.join(dir, 'automaton.yml')
      theme = File.join(dir, 'theme.yml')
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
      File.write(
        theme,
        <<~YAML
          stroke: '#ef4444'
          state_fill: '#fff7ed'
        YAML
      )

      _stdout, stderr, status = Open3.capture3(
        RbConfig.ruby,
        File.expand_path('../exe/graphomaton', __dir__),
        '--input',
        input,
        '--output',
        output,
        '--theme-file',
        theme
      )

      expect(status).to be_success, stderr
      expect(File.read(output)).to include('#ef4444')
    end
  end

  it 'passes SVG layout options through the CLI' do
    Dir.mktmpdir do |dir|
      input = File.join(dir, 'automaton.yml')
      output = File.join(dir, 'diagram.svg')
      File.write(
        input,
        <<~YAML
          states:
            - id: q0
              initial: true
              x: 10
              y: 10
            - id: q1
              final: true
          transitions:
            - from: q0
              to: q1
              label: a
        YAML
      )

      _stdout, stderr, status = Open3.capture3(
        RbConfig.ruby,
        File.expand_path('../exe/graphomaton', __dir__),
        '--input',
        input,
        '--output',
        output,
        '--responsive',
        '--state-radius',
        '22',
        '--fit',
        'cover',
        '--auto-size',
        '--xml-declaration',
        '--svg-id',
        'diagram-main',
        '--no-preserve-manual-positions'
      )

      content = File.read(output)
      expect(status).to be_success, stderr
      expect(content).to start_with('<?xml version="1.0" encoding="UTF-8"?>')
      expect(content).to include("width='100%'")
      expect(content).to include("height='auto'")
      expect(content).to include("id='diagram-main'")
      expect(content).to include("id='diagram-main-arrowhead'")
      expect(content).to include("r='22.0'")
      expect(content).not_to include("cx='10'")
    end
  end

  it 'passes SVG label options through the CLI' do
    Dir.mktmpdir do |dir|
      input = File.join(dir, 'automaton.yml')
      output = File.join(dir, 'diagram.svg')
      File.write(
        input,
        <<~YAML
          states:
            - id: q0
              initial: true
              label: VeryLongStateName
            - id: q1
              final: true
          transitions:
            - from: q0
              to: q1
              label: this transition label should wrap
        YAML
      )

      _stdout, stderr, status = Open3.capture3(
        RbConfig.ruby,
        File.expand_path('../exe/graphomaton', __dir__),
        '--input',
        input,
        '--output',
        output,
        '--wrap-labels',
        '--max-transition-label-width',
        '60',
        '--state-wrap',
        '--max-state-label-width',
        '50',
        '--label-tooltips',
        '--no-label-background',
        '--show-final-arrows'
      )

      content = File.read(output)
      expect(status).to be_success, stderr
      expect(content).to include('<tspan')
      expect(content).to include('<title>this transition label should wrap</title>')
      expect(content).not_to include("class='label-bg'")
      expect(content).to include("class='final-transition'")
    end
  end

  it 'ignores options that do not apply to the selected output format' do
    Dir.mktmpdir do |dir|
      input = File.join(dir, 'automaton.yml')
      output = File.join(dir, 'diagram.dot')
      File.write(
        input,
        <<~YAML
          states:
            - id: q0
              initial: true
            - id: q1
          transitions:
            - from: q0
              to: q1
              label: a
        YAML
      )

      _stdout, stderr, status = Open3.capture3(
        RbConfig.ruby,
        File.expand_path('../exe/graphomaton', __dir__),
        '--input',
        input,
        '--output',
        output,
        '--responsive',
        '--fit',
        'cover',
        '--cdn',
        '/assets/mermaid.min.js',
        '--show-source',
        '--scale',
        '2',
        '--converter',
        'magick',
        '--rank-constraints'
      )

      expect(status).to be_success, stderr
      content = File.read(output)
      expect(content).to include('digraph finite_state_machine')
      expect(content).to include('{ rank=source; "q0"; }')
    end
  end

  it 'passes Mermaid HTML options through the CLI' do
    Dir.mktmpdir do |dir|
      input = File.join(dir, 'automaton.yml')
      output = File.join(dir, 'diagram.html')
      mermaid_script = File.join(dir, 'mermaid.min.js')
      File.write(
        input,
        <<~YAML
          states:
            - id: q0
              initial: true
              metadata:
                note: Entry state
            - id: q1
              final: true
          transitions:
            - from: q0
              to: q1
              label: a
        YAML
      )
      File.write(mermaid_script, 'window.__inlineMermaid = true;')

      _stdout, stderr, status = Open3.capture3(
        RbConfig.ruby,
        File.expand_path('../exe/graphomaton', __dir__),
        '--input',
        input,
        '--output',
        output,
        '--title',
        'Automaton',
        '--lang',
        'en',
        '--offline',
        '--cdn',
        mermaid_script,
        '--inline-mermaid',
        '--show-source',
        '--notes',
        '--class-defs'
      )

      content = File.read(output)
      expect(status).to be_success, stderr
      expect(content).to include('<title>Automaton</title>')
      expect(content).to include('<html lang="en">')
      expect(content).to include('window.__inlineMermaid = true;')
      expect(content).to include('class="mermaid-source"')
      expect(content).to include('note right of q0: Entry state')
      expect(content).to include('classDef initial')
    end
  end
end
