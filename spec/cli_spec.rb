# frozen_string_literal: true

require 'open3'
require 'rbconfig'
require 'tmpdir'
require 'json'

RSpec.describe 'graphomaton CLI' do
  it 'prints its version without input files' do
    stdout, stderr, status = Open3.capture3(
      RbConfig.ruby,
      File.expand_path('../exe/graphomaton', __dir__),
      '--version'
    )

    expect(status).to be_success, stderr
    expect(stdout).to eq("#{Graphomaton::VERSION}\n")
  end

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

  it 'reads YAML from stdin and writes a selected format to stdout' do
    stdout, stderr, status = Open3.capture3(
      RbConfig.ruby,
      File.expand_path('../exe/graphomaton', __dir__),
      '--input', '-',
      '--output', '-',
      '--format', 'svg',
      stdin_data: "states: [q0]\ninitial: q0\n"
    )

    expect(status).to be_success, stderr
    expect(stdout).to start_with('<svg')
    expect(stderr).to eq('')
  end

  it 'detects JSON input from stdin' do
    stdout, stderr, status = Open3.capture3(
      RbConfig.ruby,
      File.expand_path('../exe/graphomaton', __dir__),
      '-i', '-',
      '-o', '-',
      '-f', 'dot',
      stdin_data: JSON.generate(states: ['q0'])
    )

    expect(status).to be_success, stderr
    expect(stdout).to start_with("digraph finite_state_machine {\n")
  end

  it 'requires an explicit output format for stdout' do
    _stdout, stderr, status = Open3.capture3(
      RbConfig.ruby,
      File.expand_path('../exe/graphomaton', __dir__),
      '-i', '-',
      '-o', '-',
      stdin_data: "states: [q0]\n"
    )

    expect(status.exitstatus).to eq(2)
    expect(stderr).to include('--format is required')
  end

  it 'does not overwrite an existing file with no-clobber' do
    Dir.mktmpdir do |dir|
      input = File.join(dir, 'automaton.yml')
      output = File.join(dir, 'diagram.svg')
      File.write(input, "states: [q0]\n")
      File.write(output, 'original')

      _stdout, stderr, status = Open3.capture3(
        RbConfig.ruby,
        File.expand_path('../exe/graphomaton', __dir__),
        '-i', input,
        '-o', output,
        '--no-clobber'
      )

      expect(status.exitstatus).to eq(6)
      expect(stderr).to include('Output file already exists')
      expect(File.read(output)).to eq('original')
    end
  end

  it 'passes accessible SVG metadata and transition merge options' do
    stdout, stderr, status = Open3.capture3(
      RbConfig.ruby,
      File.expand_path('../exe/graphomaton', __dir__),
      '-i', '-',
      '-o', '-',
      '-f', 'svg',
      '--title', 'Machine',
      '--description', 'Accepts one token',
      '--no-merge-parallel-transitions',
      stdin_data: "states: [q0, q1]\ntransitions: [[q0, q1, a], [q0, q1, b]]\n"
    )

    expect(status).to be_success, stderr
    expect(stdout).to include('<title')
    expect(stdout).to include('Machine</title>')
    expect(stdout).to include('Accepts one token</desc>')
    expect(stdout.scan(/class=['"]transition-label['"]/).size).to eq(2)
  end

  it 'enforces configured input resource limits before rendering' do
    _stdout, stderr, status = Open3.capture3(
      RbConfig.ruby,
      File.expand_path('../exe/graphomaton', __dir__),
      '-i', '-',
      '-o', '-',
      '-f', 'svg',
      '--max-input-bytes', '8',
      stdin_data: "states: [q0]\n"
    )

    expect(status.exitstatus).to eq(3)
    expect(stderr).to include('exceeds max_input_bytes')
  end

  it 'writes a theme gallery without an input automaton' do
    Dir.mktmpdir do |dir|
      output = File.join(dir, 'themes.html')
      theme_file = File.join(dir, 'theme.yml')
      File.write(
        theme_file,
        <<~YAML
          stroke: '#ff0000'
          state_fill: '#ffffff'
        YAML
      )

      _stdout, stderr, status = Open3.capture3(
        RbConfig.ruby,
        File.expand_path('../exe/graphomaton', __dir__),
        '--theme-gallery',
        '--output',
        output,
        '--theme-file',
        theme_file,
        '--theme-gallery-animated',
        '--title',
        'Themes'
      )

      content = File.read(output)
      expect(status).to be_success, stderr
      expect(content).to include('<title>Themes</title>')
      expect(content).to include('class="theme-gallery"')
      expect(content).to include('custom')
      expect(content).to include('#ff0000')
      expect(content).to include('graphomaton-gallery-dash')
      expect(content).to include('<svg')
    end
  end

  it 'lists built-in themes without an input automaton' do
    stdout, stderr, status = Open3.capture3(
      RbConfig.ruby,
      File.expand_path('../exe/graphomaton', __dir__),
      '--list-themes'
    )

    expect(status).to be_success, stderr
    expect(stdout).to include("light\n")
    expect(stdout).to include("dark\n")
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

  it 'validates automaton references by default' do
    Dir.mktmpdir do |dir|
      input = File.join(dir, 'automaton.yml')
      output = File.join(dir, 'diagram.svg')
      File.write(
        input,
        <<~YAML
          states:
            - id: q0
          transitions:
            - from: q0
              to: missing
              label: a
        YAML
      )

      _stdout, stderr, status = Open3.capture3(
        RbConfig.ruby,
        File.expand_path('../exe/graphomaton', __dir__),
        '--input',
        input,
        '--output',
        output
      )

      expect(status).not_to be_success
      expect(stderr).to include('Transition 0 target "missing" is not defined')
      expect(File.exist?(output)).to be false
    end
  end

  it 'can explicitly skip reference validation' do
    Dir.mktmpdir do |dir|
      input = File.join(dir, 'automaton.yml')
      output = File.join(dir, 'diagram.svg')
      File.write(input, "states: [q0]\ntransitions: [[q0, missing, a]]\n")

      _stdout, stderr, status = Open3.capture3(
        RbConfig.ruby,
        File.expand_path('../exe/graphomaton', __dir__),
        '--input', input,
        '--output', output,
        '--no-validate'
      )

      expect(status).to be_success, stderr
      expect(File.read(output)).to include('<svg')
    end
  end

  it 'reports malformed input without a backtrace' do
    Dir.mktmpdir do |dir|
      input = File.join(dir, 'broken.json')
      output = File.join(dir, 'diagram.svg')
      File.write(input, '{broken')

      _stdout, stderr, status = Open3.capture3(
        RbConfig.ruby,
        File.expand_path('../exe/graphomaton', __dir__),
        '--input', input,
        '--output', output
      )

      expect(status.exitstatus).to eq(3)
      expect(stderr).to include('Input error:')
      expect(stderr).not_to include('from ')
      expect(File.exist?(output)).to be false
    end
  end

  it 'infers output formats from uppercase extensions' do
    Dir.mktmpdir do |dir|
      input = File.join(dir, 'automaton.yml')
      output = File.join(dir, 'diagram.SVG')
      File.write(input, "states: [q0]\n")

      _stdout, stderr, status = Open3.capture3(
        RbConfig.ruby,
        File.expand_path('../exe/graphomaton', __dir__),
        input,
        output
      )

      expect(status).to be_success, stderr
      expect(File.read(output)).to include('<svg')
    end
  end

  it 'rejects extra positional arguments' do
    _stdout, stderr, status = Open3.capture3(
      RbConfig.ruby,
      File.expand_path('../exe/graphomaton', __dir__),
      'input.yml',
      'output.svg',
      'unexpected'
    )

    expect(status.exitstatus).to eq(2)
    expect(stderr).to include('Unexpected arguments: unexpected')
  end

  it 'rejects invalid numeric options without a backtrace' do
    _stdout, stderr, status = Open3.capture3(
      RbConfig.ruby,
      File.expand_path('../exe/graphomaton', __dir__),
      '--width',
      '-1'
    )

    expect(status.exitstatus).to eq(2)
    expect(stderr).to include('--width must be positive and finite')
    expect(stderr).not_to include('from ')
  end

  it 'rejects options that the selected output format cannot use' do
    _stdout, stderr, status = Open3.capture3(
      RbConfig.ruby,
      File.expand_path('../exe/graphomaton', __dir__),
      '-i', '-',
      '-o', '-',
      '-f', 'dot',
      '--layout', 'circle',
      stdin_data: "states: [q0]\n"
    )

    expect(status.exitstatus).to eq(2)
    expect(stderr).to include('--layout not supported for dot output')
    expect(stderr).not_to include('from ')
  end

  it 'reports an unknown output format as a usage error' do
    _stdout, stderr, status = Open3.capture3(
      RbConfig.ruby,
      File.expand_path('../exe/graphomaton', __dir__),
      '-i', '-',
      '-o', '-',
      '-f', 'unknown',
      stdin_data: "states: [q0]\n"
    )

    expect(status.exitstatus).to eq(2)
    expect(stderr).to include('Unknown format')
  end

  it 'can print SVG layout warnings before rendering' do
    Dir.mktmpdir do |dir|
      input = File.join(dir, 'automaton.yml')
      output = File.join(dir, 'diagram.svg')
      File.write(
        input,
        <<~YAML
          states:
            - id: q0
              x: 10
              y: 10
        YAML
      )

      _stdout, stderr, status = Open3.capture3(
        RbConfig.ruby,
        File.expand_path('../exe/graphomaton', __dir__),
        '--input',
        input,
        '--output',
        output,
        '--layout-warnings'
      )

      expect(status).to be_success, stderr
      expect(stderr).to include('State "q0" may be clipped horizontally')
      expect(stderr).to include('State "q0" may be clipped vertically')
      expect(File.read(output)).to include('<svg')
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
        '--padding',
        '40',
        '--node-spacing',
        '140',
        '--rank-spacing',
        '160',
        '--force-iterations',
        '5',
        '--layout-seed',
        '42',
        '--initial-position',
        'start',
        '--final-position',
        'end',
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

  it 'passes graphviz layout command through the CLI' do
    Dir.mktmpdir do |dir|
      input = File.join(dir, 'automaton.yml')
      output = File.join(dir, 'diagram.svg')
      graphviz = File.join(dir, 'fake_dot')
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
      File.write(
        graphviz,
        <<~'RUBY'
          #!/usr/bin/env ruby
          abort 'expected -Tplain' unless ARGV == ['-Tplain']

          STDIN.read
          puts <<~PLAIN
            graph 1 2 1
            node q0 0 0 0.75 0.5 q0 solid circle black lightgrey
            node q1 2 0 0.75 0.5 q1 solid circle black lightgrey
            stop
          PLAIN
        RUBY
      )
      File.chmod(0o755, graphviz)

      _stdout, stderr, status = Open3.capture3(
        RbConfig.ruby,
        File.expand_path('../exe/graphomaton', __dir__),
        '--input',
        input,
        '--output',
        output,
        '--layout',
        'graphviz',
        '--graphviz-command',
        graphviz
      )

      expect(status).to be_success, stderr
      expect(File.read(output)).to include('<svg')
    end
  end

  it 'passes SVG group folding through the CLI' do
    Dir.mktmpdir do |dir|
      input = File.join(dir, 'automaton.yml')
      output = File.join(dir, 'diagram.svg')
      File.write(
        input,
        <<~YAML
          states:
            - id: q0
              x: 100
              y: 100
              metadata:
                group: alpha
            - id: q1
              x: 220
              y: 100
              metadata:
                group: alpha
            - id: q2
              x: 340
              y: 100
          transitions:
            - from: q1
              to: q2
              label: exit
        YAML
      )

      _stdout, stderr, status = Open3.capture3(
        RbConfig.ruby,
        File.expand_path('../exe/graphomaton', __dir__),
        '--input',
        input,
        '--output',
        output,
        '--layout',
        'manual',
        '--fold-groups'
      )

      content = File.read(output)
      expect(status).to be_success, stderr
      expect(content).to include("data-folded-group='alpha'")
      expect(content).to include("data-from='group:alpha'")
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
        '--html-tooltips',
        '--rotate-labels',
        '--no-label-background',
        '--show-final-arrows'
      )

      content = File.read(output)
      expect(status).to be_success, stderr
      expect(content).to include('<tspan')
      expect(content).to include('<title>this transition label should wrap</title>')
      expect(content).to include("data-tooltip='VeryLongStateName'")
      expect(content).to include('transform=')
      expect(content).not_to include("class='label-bg'")
      expect(content).to include("class='final-transition'")
    end
  end

  it 'passes SVG automatic state radius options through the CLI' do
    Dir.mktmpdir do |dir|
      input = File.join(dir, 'automaton.yml')
      output = File.join(dir, 'diagram.svg')
      File.write(
        input,
        <<~YAML
          states:
            - id: q0
              label: ExtremelyLongStateNameForRadius
        YAML
      )

      _stdout, stderr, status = Open3.capture3(
        RbConfig.ruby,
        File.expand_path('../exe/graphomaton', __dir__),
        '--input',
        input,
        '--output',
        output,
        '--auto-state-radius',
        '--min-state-radius',
        '44',
        '--max-state-radius',
        '48'
      )

      expect(status).to be_success, stderr
      expect(File.read(output)).to include("r='48.0'")
    end
  end

  it 'passes SVG transition ordering and highlight options through the CLI' do
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
            - id: q2
          transitions:
            - from: q0
              to: q1
              label: b
            - from: q0
              to: q1
              label: a
            - from: q2
              to: q2
              label: loop
        YAML
      )

      _stdout, stderr, status = Open3.capture3(
        RbConfig.ruby,
        File.expand_path('../exe/graphomaton', __dir__),
        '--input',
        input,
        '--output',
        output,
        '--sort-labels',
        '--highlight-transition',
        'q0:q1:a, b',
        '--loop-position',
        'right'
      )

      content = File.read(output)
      expect(status).to be_success, stderr
      expect(content).to include('a, b')
      expect(content).to include('highlighted-transition')
      expect(content).to include('loop')
    end
  end

  it 'passes SVG label background and arrow options through the CLI' do
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

      _stdout, stderr, status = Open3.capture3(
        RbConfig.ruby,
        File.expand_path('../exe/graphomaton', __dir__),
        '--input',
        input,
        '--output',
        output,
        '--label-padding',
        '20',
        '--label-radius',
        '9',
        '--label-border',
        '--initial-arrow-length',
        '70',
        '--initial-arrow-label',
        'begin',
        '--final-arrow-length',
        '80',
        '--final-arrow-label',
        'done',
        '--show-final-arrows'
      )

      content = File.read(output)
      expect(status).to be_success, stderr
      expect(content).to include("class='label-bg'")
      expect(content).to include("rx='9.0'")
      expect(content).to include('begin')
      expect(content).to include('done')
    end
  end

  it 'passes SVG style embedding options through the CLI' do
    Dir.mktmpdir do |dir|
      input = File.join(dir, 'automaton.yml')
      output = File.join(dir, 'diagram.svg')
      File.write(
        input,
        <<~YAML
          states:
            - id: q0
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
        '--css-variables'
      )

      content = File.read(output)
      expect(status).to be_success, stderr
      expect(content).to include('--graphomaton-stroke')

      _stdout, stderr, status = Open3.capture3(
        RbConfig.ruby,
        File.expand_path('../exe/graphomaton', __dir__),
        '--input',
        input,
        '--output',
        output,
        '--no-embed-styles'
      )

      expect(status).to be_success, stderr
      expect(File.read(output)).not_to include('<style>')
    end
  end

  it 'passes SVG styling and analysis options through the CLI' do
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
            - id: dead
            - id: trap
          transitions:
            - from: q0
              to: q1
              label: a
            - from: q1
              to: q0
              label: back
            - from: dead
              to: trap
              label: b
            - from: trap
              to: trap
              label: c
        YAML
      )

      _stdout, stderr, status = Open3.capture3(
        RbConfig.ruby,
        File.expand_path('../exe/graphomaton', __dir__),
        '--input',
        input,
        '--output',
        output,
        '--state-shape',
        'ellipse',
        '--edge-style',
        'orthogonal',
        '--arrow-shape',
        'vee',
        '--arrow-size',
        '16',
        '--state-stroke-width',
        '4',
        '--transition-stroke-width',
        '3',
        '--state-effect',
        'shadow',
        '--font-family',
        'Noto Sans',
        '--state-font-weight',
        '700',
        '--transition-font-weight',
        '600',
        '--scc-groups',
        '--highlight-unreachable',
        '--unreachable-zone',
        'right',
        '--highlight-dead-states',
        '--highlight-initial-state',
        '--highlight-final-states'
      )

      content = File.read(output)
      expect(status).to be_success, stderr
      expect(content).to include('<ellipse')
      expect(content).to include('stroke-width: 4.0')
      expect(content).to include('stroke-width: 3.0')
      expect(content).to include('font-family: Noto Sans')
      expect(content).to include('font-weight: 700')
      expect(content).to include('font-weight: 600')
      expect(content).to include('drop-shadow')
      expect(content).to include("class='state-group-box'")
      expect(content).to include("cx='720.0'")
      expect(content).to include("class='state initial-state'")
      expect(content).to include('unreachable-state')
      expect(content).to include('dead-state')
      expect(content).to include('trap-state')
      expect(content).to include('accepting-state')
    end
  end

  it 'reports every option that does not apply to the selected output format' do
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

      expect(status.exitstatus).to eq(2)
      expect(stderr).to include('--fit')
      expect(stderr).to include('--responsive')
      expect(stderr).to include('--converter')
      expect(stderr).to include('--scale')
      expect(stderr).to include('--cdn')
      expect(stderr).to include('--show-source')
      expect(File.exist?(output)).to be false
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
        '--pan-zoom',
        '--mathjax',
        '--mathjax-cdn',
        '/assets/mathjax.js',
        '--notes',
        '--class-defs'
      )

      content = File.read(output)
      expect(status).to be_success, stderr
      expect(content).to include('<title>Automaton</title>')
      expect(content).to include('<html lang="en">')
      expect(content).to include('window.__inlineMermaid = true;')
      expect(content).to include('class="mermaid-source"')
      expect(content).to include('data-pan-zoom-viewer')
      expect(content).to include('<script defer src="/assets/mathjax.js"></script>')
      expect(content).to include('note right of q0: Entry state')
      expect(content).to include('classDef initial')
    end
  end
end
