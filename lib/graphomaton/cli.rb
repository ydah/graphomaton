# frozen_string_literal: true

require 'optparse'
require_relative '../graphomaton'
require_relative 'cli/config'

class Graphomaton
  class CLI
    EXIT_SUCCESS = 0
    EXIT_USAGE = 2
    EXIT_INPUT = 3
    EXIT_VALIDATION = 4
    EXIT_LAYOUT = 5
    EXIT_EXPORT = 6
    EXIT_SECURITY = 7
    COMMANDS = %w[render validate themes list doctor completion man].freeze
    COMPLETION_SHELLS = %w[bash zsh fish].freeze
    COMPLETION_WORDS = %w[
      render validate themes list doctor completion man formats layouts converters
      --input --input-format --output --format --config --no-clobber --force --validate
      --no-validate --profile --diagnostics --fail-on-warning --strict-semantics --layout-warnings
      --width --height --theme --theme-file --layout --direction --fit --padding
      --node-spacing --rank-spacing --force-iterations --layout-seed --graphviz-command
      --max-metadata-depth --max-label-length --max-group-depth
      --responsive --state-radius --state-shape --edge-style --wrap-labels --title
      --description --cdn --offline --inline-mermaid --inline-mathjax --self-contained
      --nonce --csp --csp-policy --mermaid-sha256 --mathjax-sha256 --version --help
    ].freeze

    def initialize(stdin: $stdin, stdout: $stdout, stderr: $stderr)
      @stdin = stdin
      @stdout = stdout
      @stderr = stderr
    end

    def run(arguments = ARGV)
      @debug = arguments.include?('--debug')
      catch(:graphomaton_cli_exit) do
        execute(arguments.dup)
        EXIT_SUCCESS
      end
    rescue OptionParser::ParseError => e
      report_exception(e)
      EXIT_USAGE
    rescue JSON::ParserError, Psych::Exception, ArgumentError, SystemCallError => e
      report_exception(e)
      EXIT_INPUT
    rescue Graphomaton::SecurityError => e
      report_exception(e)
      EXIT_SECURITY
    rescue Graphomaton::LayoutError => e
      report_exception(e)
      EXIT_LAYOUT
    rescue Graphomaton::Error => e
      report_exception(e)
      EXIT_EXPORT
    end

    private

    def halt(status)
      throw :graphomaton_cli_exit, status
    end

    def warn(message)
      @stderr.puts(message)
    end

    def puts(message)
      @stdout.puts(message)
    end

    def report_exception(error, prefix: nil)
      message = @debug ? error.full_message : error.message
      message = "#{prefix}: #{message}" if prefix
      warn(message)
    end

def load_theme_file(path)
  File.open(path, 'rb') do |theme_input|
    case File.extname(path).downcase
    when '.json'
      Graphomaton.theme_from_json(theme_input)
    when '.yml', '.yaml'
      Graphomaton.theme_from_yaml(theme_input)
    else
      raise ArgumentError, 'Theme file must use .json, .yml, or .yaml extension'
    end
  end
rescue JSON::ParserError, Psych::Exception, ArgumentError, SystemCallError => e
  report_exception(e, prefix: 'Theme input error')
  halt(EXIT_INPUT)
end

def parse_automaton(source, format, limits)
  case format.to_s.delete_prefix('.').downcase
  when 'json'
    Graphomaton.from_json(source, **limits)
  when 'yml', 'yaml'
    Graphomaton.from_yaml(source, **limits)
  else
    raise ArgumentError, 'Input format must be json, yml, or yaml'
  end
end

def load_automaton(path, input_format:, limits:)
  if path == '-'
    payload = @stdin.read(limits.fetch(:max_input_bytes) + 1)
    detected_format = input_format || (payload.lstrip.start_with?('{', '[') ? :json : :yaml)
    return parse_automaton(payload, detected_format, limits)
  end

  extension = File.extname(path)
  if input_format.nil? && !%w[.json .yml .yaml].include?(extension.downcase)
    raise ArgumentError, 'Input file must use .json, .yml, or .yaml extension'
  end
  format = input_format || extension
  File.open(path, 'rb') { |source| parse_automaton(source, format, limits) }
end

def validate_cli_numeric_options!(options)
  positive = %i[
    width height scale timeout max_output_bytes max_input_bytes max_states max_transitions
    max_metadata_depth max_label_length max_group_depth
    state_radius min_state_radius max_state_radius
    state_stroke_width transition_stroke_width arrow_size initial_arrow_length final_arrow_length
  ]
  nonnegative = %i[
    padding node_spacing rank_spacing force_iterations max_transition_label_width
    max_state_label_width label_padding label_radius
  ]

  positive.each do |name|
    value = options[name]
    next if value.nil?

    valid = value.is_a?(Numeric) && value.real? && value.to_f.finite? && value.positive?
    raise OptionParser::InvalidArgument, "--#{name.to_s.tr('_', '-')} must be positive and finite" unless valid
  end
  nonnegative.each do |name|
    value = options[name]
    next if value.nil?

    valid = value.is_a?(Numeric) && value.real? && value.to_f.finite? && value >= 0
    raise OptionParser::InvalidArgument, "--#{name.to_s.tr('_', '-')} must be non-negative and finite" unless valid
  end
end

def validate_format_options!(options, format)
  svg_backed = %i[svg png pdf webp]
  converted = %i[png pdf webp]
  support = {}
  %i[
    layout_warnings layout fit padding node_spacing rank_spacing force_iterations layout_seed
    graphviz_command auto_density_spacing initial_position final_position responsive state_radius
    auto_state_radius min_state_radius max_state_radius state_stroke_width transition_stroke_width
    state_shape edge_style arrow_shape arrow_size state_effect font_family state_font_weight
    transition_font_weight preserve_manual_positions auto_size xml_declaration pretty minify
    css_variables embed_styles svg_id wrap max_transition_label_width state_wrap
    max_state_label_width label_tooltips html_tooltips sort_labels rotate_labels label_padding
    label_radius label_border label_background initial_arrow_length initial_arrow_label
    final_arrow_length final_arrow_label show_final_arrows scc_groups fold_groups
    highlight_unreachable unreachable_zone highlight_dead_states highlight_initial_state
    highlight_final_states highlight_transitions loop_position merge_parallel_transitions description
  ].each { |name| support[name] = svg_backed }
  support[:theme] = svg_backed + %i[html dot plantuml]
  support[:theme_file] = svg_backed + %i[dot plantuml]
  support[:direction] = svg_backed + %i[html mermaid dot plantuml]
  support[:title] = svg_backed + [:html]
  %i[converter timeout max_output_bytes].each { |name| support[name] = converted }
  support[:scale] = [:png]
  %i[
    cdn offline inline_mermaid lang show_source pan_zoom mathjax mathjax_cdn inline_mathjax
    self_contained nonce csp mermaid_sha256 mathjax_sha256
  ].each { |name| support[name] = [:html] }
  support[:notes] = %i[html mermaid plantuml]
  support[:class_defs] = %i[html mermaid]
  support[:rank_constraints] = [:dot]

  unsupported = support.each_key.select { |name| options.key?(name) && !support.fetch(name).include?(format) }
  unless unsupported.empty?
    flags = unsupported.map { |name| "--#{name.to_s.tr('_', '-')}" }.join(', ')
    raise OptionParser::InvalidArgument, "#{flags} not supported for #{format} output"
  end
  if format == :html && options[:theme].is_a?(Hash)
    raise OptionParser::InvalidArgument, 'custom theme mappings are not supported for html output'
  end
end

def extract_command(arguments)
  return :render unless COMMANDS.include?(arguments.first)

  arguments.shift.to_sym
end

def option_value(arguments, long, short = nil)
  arguments.each_with_index do |argument, index|
    return argument.split('=', 2).last if argument.start_with?("#{long}=")
    return arguments[index + 1] if argument == long || (short && argument == short)
  end
  nil
end

def format_hint(arguments)
  explicit = option_value(arguments, '--format', '-f')
  return Graphomaton::EXPORTERS.resolve(explicit) if explicit

  output = option_value(arguments, '--output', '-o')
  return Graphomaton::EXPORTERS.resolve(File.extname(output)) if output && output != '-'

  arguments.reject { |argument| argument.start_with?('-') }.reverse_each do |candidate|
    return Graphomaton::EXPORTERS.resolve(File.extname(candidate))
  rescue ArgumentError
    next
  end
  nil
rescue ArgumentError
  nil
end

def config_path(arguments)
  explicit = option_value(arguments, '--config')
  return [explicit, true] if explicit

  environment_path = ENV['GRAPHOMATON_CONFIG']
  return [environment_path, true] if environment_path && !environment_path.empty?

  [Config::DEFAULT_PATH, false]
end

def environment_options
  mappings = {
    'GRAPHOMATON_FORMAT' => [:format, ->(value) { value.to_sym }],
    'GRAPHOMATON_THEME' => [:theme, ->(value) { value.to_sym }],
    'GRAPHOMATON_LAYOUT' => [:layout, ->(value) { value.to_sym }],
    'GRAPHOMATON_WIDTH' => [:width, ->(value) { Integer(value, 10) }],
    'GRAPHOMATON_HEIGHT' => [:height, ->(value) { Integer(value, 10) }]
  }
  mappings.each_with_object({}) do |(environment_name, (option_name, parser)), options|
    value = ENV[environment_name]
    options[option_name] = parser.call(value) if value && !value.empty?
  end
rescue ArgumentError => e
  raise OptionParser::InvalidArgument, "Invalid Graphomaton environment option: #{e.message}"
end

def execute_list(arguments)
  target = arguments.shift
  unless arguments.empty? || target.nil?
    warn "Unexpected arguments: #{arguments.join(' ')}"
    halt(EXIT_USAGE)
  end

  values = case target
           when 'formats' then Graphomaton::EXPORTERS.formats
           when 'layouts' then Graphomaton::LAYOUT_OPTIONS
           when 'themes' then Graphomaton::Theme.available_names
           when 'converters' then %w[rsvg magick convert]
           else
             warn 'Usage: graphomaton list formats|layouts|themes|converters'
             halt(EXIT_USAGE)
           end
  puts values.join("\n")
end

def execute_doctor(arguments)
  unless arguments.empty?
    warn "Unexpected arguments: #{arguments.join(' ')}"
    halt(EXIT_USAGE)
  end

  checks = {
    graphomaton: Graphomaton::VERSION,
    ruby: RUBY_DESCRIPTION,
    graphviz: renderer_health('dot', '-V'),
    rsvg: renderer_health('rsvg-convert', '--version'),
    imagemagick: renderer_health('magick', '-version', fallback: 'convert'),
    mermaid: renderer_health('mmdc', '--version'),
    plantuml: renderer_health('plantuml', '-version'),
    png: Graphomaton::Exporters::Png.available? ? 'available' : 'missing',
    pdf: Graphomaton::Exporters::Pdf.available? ? 'available' : 'missing',
    webp: Graphomaton::Exporters::Webp.available? ? 'available' : 'missing'
  }
  checks.each { |name, value| puts "#{name}: #{value}" }
end

def execute_themes(arguments)
  unless arguments.empty?
    warn "Unexpected arguments: #{arguments.join(' ')}"
    halt(EXIT_USAGE)
  end

  puts Graphomaton::Theme.available_names.join("\n")
end

def execute_completion(arguments)
  shell = arguments.shift
  unless COMPLETION_SHELLS.include?(shell) && arguments.empty?
    warn "Usage: graphomaton completion #{COMPLETION_SHELLS.join('|')}"
    halt(EXIT_USAGE)
  end

  words = COMPLETION_WORDS.join(' ')
  output = case shell
           when 'bash'
             <<~BASH
               _graphomaton_completion() {
                 COMPREPLY=( $(compgen -W '#{words}' -- "${COMP_WORDS[COMP_CWORD]}") )
               }
               complete -F _graphomaton_completion graphomaton
             BASH
           when 'zsh'
             <<~ZSH
               #compdef graphomaton
               _arguments '*:graphomaton command or option:(#{words})'
             ZSH
           when 'fish'
             COMPLETION_WORDS.map { |word| "complete -c graphomaton -f -a '#{word}'" }.join("\n") + "\n"
           end
  @stdout.write(output)
end

def execute_man(arguments)
  unless arguments.empty?
    warn "Unexpected arguments: #{arguments.join(' ')}"
    halt(EXIT_USAGE)
  end

  @stdout.write <<~MANPAGE
    .TH GRAPHOMATON 1 "2026-09-08" "Graphomaton #{Graphomaton::VERSION}" "User Commands"
    .SH NAME
    graphomaton \- validate, analyze, and render finite-state machines
    .SH SYNOPSIS
    .B graphomaton
    [render] -i INPUT -o OUTPUT [options]
    .br
    .B graphomaton validate
    INPUT [--diagnostics text|json]
    .SH COMMANDS
    render, validate, themes, list, doctor, completion, and man.
    .SH EXIT STATUS
    0 success; 2 usage; 3 input; 4 validation; 5 layout; 6 export; 7 security.
    .SH FILES
    .I .graphomaton.yml
    supplies defaults overridden by environment variables and command-line options.
    .SH SEE ALSO
    https://github.com/ydah/graphomaton
  MANPAGE
end

def renderer_health(command, *version_arguments, fallback: nil)
  path = Graphomaton::ProcessRunner.which(command)
  path ||= Graphomaton::ProcessRunner.which(fallback) if fallback
  return 'missing' unless path

  stdout, stderr, status = Graphomaton::ProcessRunner.capture3(
    path,
    *version_arguments,
    timeout: 3,
    max_stdout_bytes: 64 * 1024,
    max_stderr_bytes: 64 * 1024
  )
  version = [stdout, stderr].map(&:strip).find { |text| !text.empty? }
  version = version.to_s.lines.first.to_s.strip
  status.success? && !version.empty? ? "#{path} (#{version})" : "#{path} (version unavailable)"
rescue Graphomaton::ProcessRunner::Error, SystemCallError
  "#{path} (version unavailable)"
end

def emit_diagnostics(diagnostics, format:, stream:)
  if format.to_sym == :json
    payload = diagnostics.map do |diagnostic|
      {
        code: diagnostic.code,
        severity: diagnostic.severity,
        path: diagnostic.path,
        message: diagnostic.message,
        hint: diagnostic.hint
      }.compact
    end
    stream.puts(JSON.generate(payload))
  else
    diagnostics.each do |diagnostic|
      location = diagnostic.path.empty? ? '' : " at #{diagnostic.path.join('.')}"
      stream.puts("#{diagnostic.severity}: #{diagnostic.code}#{location}: #{diagnostic.message}")
      stream.puts("  hint: #{diagnostic.hint}") if diagnostic.hint
    end
  end
end

def execute(arguments)
command = extract_command(arguments)
return execute_list(arguments) if command == :list
return execute_doctor(arguments) if command == :doctor
return execute_completion(arguments) if command == :completion
return execute_man(arguments) if command == :man
return execute_themes(arguments) if command == :themes
if arguments.include?('--version')
  puts Graphomaton::VERSION
  halt(EXIT_SUCCESS)
end

selected_config_path, config_required = config_path(arguments)
environment = environment_options
argument_format = format_hint(arguments)
selected_format = argument_format || environment[:format]
configured_options = Config.load(
  selected_config_path,
  format: selected_format,
  required: config_required
)
if selected_format.nil?
  configured_format = configured_options[:format]
  configured_output = configured_options[:output]
  configured_format ||= File.extname(configured_output) if configured_output && configured_output != '-'
  if configured_format && !configured_format.to_s.empty?
    selected_format = Graphomaton::EXPORTERS.resolve(configured_format)
    configured_options = Config.load(selected_config_path, format: selected_format, required: config_required)
  end
end
options = {
  width: 800,
  height: 600,
  max_input_bytes: Graphomaton::DEFAULT_MAX_INPUT_BYTES,
  max_states: Graphomaton::DEFAULT_MAX_STATES,
  max_transitions: Graphomaton::DEFAULT_MAX_TRANSITIONS,
  max_metadata_depth: Graphomaton::DEFAULT_MAX_METADATA_DEPTH,
  max_label_length: Graphomaton::DEFAULT_MAX_LABEL_LENGTH,
  max_group_depth: Graphomaton::DEFAULT_MAX_GROUP_DEPTH,
  validate: true
}.merge(configured_options).merge(environment)
options[:format] = argument_format if argument_format

parser = OptionParser.new do |opts|
  opts.banner = 'Usage: graphomaton [render] --input automaton.yml --output diagram.svg [options]'
  opts.separator '       graphomaton validate automaton.yml [--profile references|fsm_semantics|dfa|all]'
  opts.separator '       graphomaton list formats|layouts|themes|converters'
  opts.separator '       graphomaton themes | doctor'
  opts.separator '       graphomaton --theme-gallery --output theme_gallery.html [options]'

  opts.on('--config PATH', 'Configuration file (default: .graphomaton.yml)') { |value| options[:config] = value }
  opts.on('-i', '--input PATH', 'Input JSON or YAML file') { |value| options[:input] = value }
  opts.on('--input-format FORMAT', 'Input format for stdin or extension override') { |value| options[:input_format] = value.to_sym }
  opts.on('-o', '--output PATH', 'Output file path') { |value| options[:output] = value }
  opts.on('--no-clobber', 'Fail if the output file already exists') { options[:no_clobber] = true }
  opts.on('--force', 'Allow replacing an existing output file') { options[:no_clobber] = false }
  opts.on('-f', '--format FORMAT', 'Output format override') { |value| options[:format] = value.to_sym }
  opts.on('--[no-]validate', 'Validate automaton references before rendering (default: enabled)') { |value| options[:validate] = value }
  opts.on('--profile PROFILE', 'Validation profile: references, fsm_semantics, dfa, or all') { |value| options[:profile] = value.to_sym }
  opts.on('--diagnostics FORMAT', 'Diagnostic output: text or json') { |value| options[:diagnostics] = value.to_sym }
  opts.on('--fail-on-warning', 'Return a failure status when warnings are emitted') { options[:fail_on_warning] = true }
  opts.on('--strict-semantics', 'Reject information loss in the selected output format') { options[:strict_semantics] = true }
  opts.on('--debug', 'Include exception details in errors') { options[:debug] = true }
  opts.on('--layout-warnings', 'Print SVG layout clipping warnings before rendering') { options[:layout_warnings] = true }
  opts.on('--width WIDTH', Integer, 'Output width for size-aware formats') { |value| options[:width] = value }
  opts.on('--height HEIGHT', Integer, 'Output height for size-aware formats') { |value| options[:height] = value }
  opts.on('--scale SCALE', Float, 'PNG output scale') { |value| options[:scale] = value }
  opts.on('--converter CONVERTER', 'SVG conversion backend for PNG, PDF, or WebP') { |value| options[:converter] = value.to_sym }
  opts.on('--timeout SECONDS', Float, 'Converter timeout in seconds') { |value| options[:timeout] = value }
  opts.on('--max-output-bytes BYTES', Integer, 'Maximum converter output size') { |value| options[:max_output_bytes] = value }
  opts.on('--max-input-bytes BYTES', Integer, 'Maximum JSON or YAML input size') { |value| options[:max_input_bytes] = value }
  opts.on('--max-states COUNT', Integer, 'Maximum parsed state count') { |value| options[:max_states] = value }
  opts.on('--max-transitions COUNT', Integer, 'Maximum parsed transition count') { |value| options[:max_transitions] = value }
  opts.on('--max-metadata-depth DEPTH', Integer, 'Maximum nested metadata depth') { |value| options[:max_metadata_depth] = value }
  opts.on('--max-label-length BYTES', Integer, 'Maximum label size in bytes') { |value| options[:max_label_length] = value }
  opts.on('--max-group-depth DEPTH', Integer, 'Maximum state hierarchy depth') { |value| options[:max_group_depth] = value }
  opts.on('--theme THEME', 'Theme name') { |value| options[:theme] = value.to_sym }
  opts.on('--theme-file PATH', 'Theme JSON or YAML file') { |value| options[:theme_file] = value }
  opts.on('--theme-gallery', 'Write a standalone HTML gallery of built-in themes') { options[:theme_gallery] = true }
  opts.on('--theme-gallery-animated', 'Animate the standalone theme gallery preview') { options[:theme_gallery_animated] = true }
  opts.on('--list-themes', 'Print built-in theme names') { options[:list_themes] = true }
  opts.on('--layout LAYOUT', 'SVG layout') { |value| options[:layout] = value.to_sym }
  opts.on('--direction DIRECTION', 'Layout direction') { |value| options[:direction] = value.to_sym }
  opts.on('--fit FIT', 'Fit mode for resolved SVG positions') { |value| options[:fit] = value.to_sym }
  opts.on('--padding PADDING', Float, 'SVG layout padding') { |value| options[:padding] = value }
  opts.on('--node-spacing SPACING', Float, 'SVG node spacing') { |value| options[:node_spacing] = value }
  opts.on('--rank-spacing SPACING', Float, 'SVG rank spacing for layered layouts') { |value| options[:rank_spacing] = value }
  opts.on('--force-iterations COUNT', Integer, 'SVG force layout iteration count') { |value| options[:force_iterations] = value }
  opts.on('--layout-seed SEED', Integer, 'SVG force layout random seed') { |value| options[:layout_seed] = value }
  opts.on('--graphviz-command COMMAND', 'Graphviz dot command for graphviz SVG layout') { |value| options[:graphviz_command] = value }
  opts.on('--auto-density-spacing', 'Increase SVG spacing for dense graphs') { options[:auto_density_spacing] = true }
  opts.on('--initial-position POSITION', 'Initial state placement mode') { |value| options[:initial_position] = value.to_sym }
  opts.on('--final-position POSITION', 'Final state placement mode') { |value| options[:final_position] = value.to_sym }
  opts.on('--responsive', 'Render responsive SVG width and height attributes') { options[:responsive] = true }
  opts.on('--state-radius RADIUS', Float, 'SVG state radius') { |value| options[:state_radius] = value }
  opts.on('--auto-state-radius', 'Grow SVG state radius from state label width') { options[:auto_state_radius] = true }
  opts.on('--min-state-radius RADIUS', Float, 'Minimum SVG auto state radius') { |value| options[:min_state_radius] = value }
  opts.on('--max-state-radius RADIUS', Float, 'Maximum SVG auto state radius') { |value| options[:max_state_radius] = value }
  opts.on('--state-stroke-width WIDTH', Float, 'SVG state stroke width') { |value| options[:state_stroke_width] = value }
  opts.on('--transition-stroke-width WIDTH', Float, 'SVG transition stroke width') { |value| options[:transition_stroke_width] = value }
  opts.on('--state-shape SHAPE', 'SVG state shape') { |value| options[:state_shape] = value.to_sym }
  opts.on('--edge-style STYLE', 'SVG edge style') { |value| options[:edge_style] = value.to_sym }
  opts.on('--arrow-shape SHAPE', 'SVG arrowhead shape') { |value| options[:arrow_shape] = value.to_sym }
  opts.on('--arrow-size SIZE', Float, 'SVG arrowhead size') { |value| options[:arrow_size] = value }
  opts.on('--state-effect EFFECT', 'SVG state effect') { |value| options[:state_effect] = value.to_sym }
  opts.on('--font-family FAMILY', 'SVG font family') { |value| options[:font_family] = value }
  opts.on('--state-font-weight WEIGHT', 'SVG state font weight') { |value| options[:state_font_weight] = value }
  opts.on('--transition-font-weight WEIGHT', 'SVG transition font weight') { |value| options[:transition_font_weight] = value }
  opts.on('--no-preserve-manual-positions', 'Allow automatic layouts to reposition states with explicit coordinates') { options[:preserve_manual_positions] = false }
  opts.on('--auto-size', 'Expand SVG canvas from resolved graph bounds') { options[:auto_size] = true }
  opts.on('--xml-declaration', 'Include an XML declaration in SVG output') { options[:xml_declaration] = true }
  opts.on('--pretty', 'Pretty-print SVG output') { options[:pretty] = true }
  opts.on('--minify', 'Minify SVG output') { options[:minify] = true }
  opts.on('--css-variables', 'Emit SVG theme values as CSS variables') { options[:css_variables] = true }
  opts.on('--no-embed-styles', 'Skip embedded SVG style block') { options[:embed_styles] = false }
  opts.on('--svg-id ID', 'Stable SVG root ID prefix') { |value| options[:svg_id] = value }
  opts.on('--wrap-labels', 'Wrap long SVG transition labels') { options[:wrap] = true }
  opts.on('--max-transition-label-width WIDTH', Float, 'Maximum SVG transition label width before wrapping') { |value| options[:max_transition_label_width] = value }
  opts.on('--state-wrap', 'Wrap long SVG state labels') { options[:state_wrap] = true }
  opts.on('--max-state-label-width WIDTH', Float, 'Maximum SVG state label width before wrapping') { |value| options[:max_state_label_width] = value }
  opts.on('--label-tooltips', 'Add SVG title tooltips for labels') { options[:label_tooltips] = true }
  opts.on('--html-tooltips', 'Add SVG data-tooltip attributes for HTML wrappers') { options[:html_tooltips] = true }
  opts.on('--sort-labels', 'Sort merged SVG transition labels') { options[:sort_labels] = true }
  opts.on('--rotate-labels', 'Rotate SVG transition labels along edges') { options[:rotate_labels] = true }
  opts.on('--label-padding PADDING', Float, 'SVG transition label padding') { |value| options[:label_padding] = value }
  opts.on('--label-radius RADIUS', Float, 'SVG transition label corner radius') { |value| options[:label_radius] = value }
  opts.on('--label-border', 'Draw SVG transition label borders') { options[:label_border] = true }
  opts.on('--no-label-background', 'Hide SVG transition label backgrounds') { options[:label_background] = false }
  opts.on('--initial-arrow-length LENGTH', Float, 'SVG initial arrow length') { |value| options[:initial_arrow_length] = value }
  opts.on('--initial-arrow-label LABEL', 'SVG initial arrow label') { |value| options[:initial_arrow_label] = value }
  opts.on('--no-initial-arrow-label', 'Hide the SVG initial arrow label') { options[:initial_arrow_label] = nil }
  opts.on('--final-arrow-length LENGTH', Float, 'SVG final arrow length') { |value| options[:final_arrow_length] = value }
  opts.on('--final-arrow-label LABEL', 'SVG final arrow label') { |value| options[:final_arrow_label] = value }
  opts.on('--no-final-arrow-label', 'Hide SVG final arrow labels') { options[:final_arrow_label] = nil }
  opts.on('--show-final-arrows', 'Render native SVG arrows from final states') { options[:show_final_arrows] = true }
  opts.on('--scc-groups', 'Render SVG groups around strongly connected components') { options[:scc_groups] = true }
  opts.on('--fold-groups', 'Fold grouped SVG states into compound nodes') { options[:fold_groups] = true }
  opts.on('--highlight-unreachable', 'Highlight unreachable states in SVG output') { options[:highlight_unreachable] = true }
  opts.on('--unreachable-zone POSITION', 'Move unreachable SVG states to none, right, bottom, left, or top') { |value| options[:unreachable_zone] = value.to_sym }
  opts.on('--highlight-dead-states', 'Highlight dead and trap states in SVG output') { options[:highlight_dead_states] = true }
  opts.on('--highlight-initial-state', 'Highlight the initial state in SVG output') { options[:highlight_initial_state] = true }
  opts.on('--highlight-final-states', 'Highlight accepting states in SVG output') { options[:highlight_final_states] = true }
  opts.on('--highlight-transition SPEC', 'Highlight SVG transition FROM:TO[:LABEL]') do |value|
    parts = value.split(':', 3)
    raise OptionParser::InvalidArgument, value if parts.size < 2

    target = { from: parts[0], to: parts[1] }
    target[:label] = parts[2] if parts[2]
    options[:highlight_transitions] ||= []
    options[:highlight_transitions] << target
  end
  opts.on('--loop-position POSITION', 'SVG self-loop placement') { |value| options[:loop_position] = value.to_sym }
  opts.on('--cdn URL_OR_PATH', 'Mermaid CDN URL or local script path for HTML output') { |value| options[:cdn] = value }
  opts.on('--offline', 'Use a non-module Mermaid script tag for HTML output') { options[:offline] = true }
  opts.on('--inline-mermaid', 'Inline Mermaid script from --cdn path in HTML output') { options[:inline_mermaid] = true }
  opts.on('--inline-mathjax', 'Inline MathJax script from --mathjax-cdn path') { options[:inline_mathjax] = true }
  opts.on('--self-contained', 'Inline all configured local HTML assets') { options[:self_contained] = true }
  opts.on('--nonce NONCE', 'Add a CSP nonce to generated HTML scripts and styles') { |value| options[:nonce] = value }
  opts.on('--csp', 'Add a strict Content Security Policy meta tag (requires --nonce)') { options[:csp] = true }
  opts.on('--csp-policy POLICY', 'Add a custom Content Security Policy meta tag') { |value| options[:csp] = value }
  opts.on('--mermaid-sha256 HEX', 'Verify an inlined Mermaid asset') { |value| options[:mermaid_sha256] = value }
  opts.on('--mathjax-sha256 HEX', 'Verify an inlined MathJax asset') { |value| options[:mathjax_sha256] = value }
  opts.on('--title TITLE', 'HTML page or accessible SVG title') { |value| options[:title] = value }
  opts.on('--description TEXT', 'Accessible SVG description') { |value| options[:description] = value }
  opts.on('--lang LANG', 'HTML language code') { |value| options[:lang] = value }
  opts.on('--show-source', 'Include Mermaid source in HTML output') { options[:show_source] = true }
  opts.on('--pan-zoom', 'Add pan and zoom controls to HTML output') { options[:pan_zoom] = true }
  opts.on('--mathjax', 'Include MathJax support in HTML output') { options[:mathjax] = true }
  opts.on('--mathjax-cdn URL_OR_PATH', 'MathJax script URL or local path for HTML output') { |value| options[:mathjax_cdn] = value }
  opts.on('--notes', 'Include state metadata notes in Mermaid output') { options[:notes] = true }
  opts.on('--class-defs', 'Include Mermaid class definitions in Mermaid output') { options[:class_defs] = true }
  opts.on('--rank-constraints', 'Emit DOT rank constraints for initial and final states') { options[:rank_constraints] = true }
  opts.on('--[no-]merge-parallel-transitions', 'Merge equivalent parallel SVG transitions') { |value| options[:merge_parallel_transitions] = value }
  opts.on('--version', 'Print version') { options[:version] = true }
  opts.on('-h', '--help', 'Print help') do
    puts opts
    halt(EXIT_SUCCESS)
  end
end

begin
  parser.parse!(arguments)
  validate_cli_numeric_options!(options)
rescue OptionParser::ParseError => e
  report_exception(e)
  halt(EXIT_USAGE)
end

input_path = options[:input] || arguments.shift
output_path = options[:output]
output_path ||= arguments.shift if command == :render

unless arguments.empty?
  warn "Unexpected arguments: #{arguments.join(' ')}"
  halt(EXIT_USAGE)
end

if options[:version]
  puts Graphomaton::VERSION
  halt(EXIT_SUCCESS)
end

unless %i[text json].include?((options[:diagnostics] || :text).to_sym)
  warn '--diagnostics must be text or json'
  halt(EXIT_USAGE)
end

if options[:list_themes]
  puts Graphomaton::Theme.available_names.join("\n")
  halt(EXIT_SUCCESS)
end

if options[:theme_gallery]
  if output_path.nil?
    warn parser
    halt(EXIT_USAGE)
  end

  if options[:no_clobber] && File.exist?(output_path)
    warn "Output file already exists: #{output_path}"
    halt(EXIT_EXPORT)
  end

  themes = Graphomaton::Exporters::Svg::THEMES.dup
  themes = themes.merge(custom: load_theme_file(options[:theme_file])) if options[:theme_file]
  begin
    Graphomaton::Theme.save_gallery_html(
      output_path,
      no_clobber: options[:no_clobber],
      title: options[:title] || 'Graphomaton Theme Gallery',
      themes: themes,
      animated: options[:theme_gallery_animated]
    )
  rescue Errno::EEXIST
    warn "Output file already exists: #{output_path}"
    halt(EXIT_EXPORT)
  rescue SystemCallError => e
    report_exception(e)
    halt(EXIT_EXPORT)
  end
  halt(EXIT_SUCCESS)
end

if input_path.nil? || (command == :render && output_path.nil?)
  warn parser
  halt(EXIT_USAGE)
end

if command == :render && options[:no_clobber] && output_path != '-' && File.exist?(output_path)
  warn "Output file already exists: #{output_path}"
  halt(EXIT_EXPORT)
end

begin
  automaton = load_automaton(
    input_path,
    input_format: options[:input_format],
    limits: {
      max_input_bytes: options[:max_input_bytes],
      max_states: options[:max_states],
      max_transitions: options[:max_transitions],
      max_metadata_depth: options[:max_metadata_depth],
      max_label_length: options[:max_label_length],
      max_group_depth: options[:max_group_depth]
    }
  )
rescue JSON::ParserError, Psych::Exception, ArgumentError, SystemCallError => e
  report_exception(e, prefix: 'Input error')
  halt(EXIT_INPUT)
end

if command == :validate
  profile = (options[:profile] || :references).to_s.to_sym
  profiles = {
    references: :references,
    fsm_semantics: %i[references fsm_semantics],
    dfa: %i[references dfa],
    all: :all
  }
  unless profiles.key?(profile)
    warn "Unknown validation profile: #{profile}"
    halt(EXIT_USAGE)
  end
  diagnostics = automaton.validation_diagnostics(profile: profiles.fetch(profile))
  emit_diagnostics(diagnostics, format: options[:diagnostics] || :text, stream: @stdout)
  has_errors = diagnostics.any? { |diagnostic| diagnostic.severity == :error }
  has_warnings = diagnostics.any? { |diagnostic| diagnostic.severity == :warning }
  halt(EXIT_VALIDATION) if has_errors || (options[:fail_on_warning] && has_warnings)
  halt(EXIT_SUCCESS)
end

if options[:validate]
  begin
    automaton.validate!
  rescue Graphomaton::ValidationError => e
    report_exception(e)
    halt(EXIT_VALIDATION)
  end
end

if options[:theme_file]
  options[:theme] = load_theme_file(options[:theme_file])
end

format_name = options[:format] || File.extname(output_path).delete_prefix('.')
if output_path == '-' && options[:format].nil?
  warn '--format is required when writing to standard output'
  halt(EXIT_USAGE)
end
begin
  resolved_output_format = Graphomaton::EXPORTERS.resolve(format_name)
rescue ArgumentError => e
  report_exception(e)
  halt(EXIT_USAGE)
end
begin
  validate_format_options!(options, resolved_output_format)
rescue OptionParser::ParseError => e
  report_exception(e)
  halt(EXIT_USAGE)
end
svg_backed_format = %i[svg png pdf webp].include?(resolved_output_format)

save_options = {}
if options[:theme]
  save_options[:theme] = options[:theme] if svg_backed_format ||
                                          %i[dot plantuml].include?(resolved_output_format) ||
                                          (resolved_output_format == :html && !options[:theme].is_a?(Hash))
end
save_options[:direction] = options[:direction] if options[:direction] && (svg_backed_format || %i[html mermaid dot plantuml].include?(resolved_output_format))
if svg_backed_format
  save_options[:layout] = options[:layout] if options[:layout]
  save_options[:title] = options[:title] if options[:title]
  save_options[:description] = options[:description] if options[:description]
  save_options[:merge_parallel_transitions] = options[:merge_parallel_transitions] if options.key?(:merge_parallel_transitions)
  save_options[:fit] = options[:fit] if options[:fit]
  save_options[:padding] = options[:padding] if options[:padding]
  save_options[:node_spacing] = options[:node_spacing] if options[:node_spacing]
  save_options[:rank_spacing] = options[:rank_spacing] if options[:rank_spacing]
  save_options[:force_iterations] = options[:force_iterations] if options[:force_iterations]
  save_options[:layout_seed] = options[:layout_seed] if options[:layout_seed]
  save_options[:graphviz_command] = options[:graphviz_command] if options[:graphviz_command]
  save_options[:auto_density_spacing] = options[:auto_density_spacing] if options.key?(:auto_density_spacing)
  save_options[:initial_position] = options[:initial_position] if options[:initial_position]
  save_options[:final_position] = options[:final_position] if options[:final_position]
  save_options[:responsive] = options[:responsive] if options.key?(:responsive)
  save_options[:state_radius] = options[:state_radius] if options[:state_radius]
  save_options[:auto_state_radius] = options[:auto_state_radius] if options.key?(:auto_state_radius)
  save_options[:min_state_radius] = options[:min_state_radius] if options[:min_state_radius]
  save_options[:max_state_radius] = options[:max_state_radius] if options[:max_state_radius]
  save_options[:state_stroke_width] = options[:state_stroke_width] if options[:state_stroke_width]
  save_options[:transition_stroke_width] = options[:transition_stroke_width] if options[:transition_stroke_width]
  save_options[:state_shape] = options[:state_shape] if options[:state_shape]
  save_options[:edge_style] = options[:edge_style] if options[:edge_style]
  save_options[:arrow_shape] = options[:arrow_shape] if options[:arrow_shape]
  save_options[:arrow_size] = options[:arrow_size] if options[:arrow_size]
  save_options[:state_effect] = options[:state_effect] if options[:state_effect]
  save_options[:font_family] = options[:font_family] if options[:font_family]
  save_options[:state_font_weight] = options[:state_font_weight] if options[:state_font_weight]
  save_options[:transition_font_weight] = options[:transition_font_weight] if options[:transition_font_weight]
  save_options[:preserve_manual_positions] = options[:preserve_manual_positions] if options.key?(:preserve_manual_positions)
  save_options[:auto_size] = options[:auto_size] if options.key?(:auto_size)
  save_options[:xml_declaration] = options[:xml_declaration] if options.key?(:xml_declaration)
  save_options[:pretty] = options[:pretty] if options.key?(:pretty)
  save_options[:minify] = options[:minify] if options.key?(:minify)
  save_options[:css_variables] = options[:css_variables] if options.key?(:css_variables)
  save_options[:embed_styles] = options[:embed_styles] if options.key?(:embed_styles)
  save_options[:svg_id] = options[:svg_id] if options[:svg_id]
  save_options[:wrap] = options[:wrap] if options.key?(:wrap)
  save_options[:max_transition_label_width] = options[:max_transition_label_width] if options[:max_transition_label_width]
  save_options[:state_wrap] = options[:state_wrap] if options.key?(:state_wrap)
  save_options[:max_state_label_width] = options[:max_state_label_width] if options[:max_state_label_width]
  save_options[:label_tooltips] = options[:label_tooltips] if options.key?(:label_tooltips)
  save_options[:html_tooltips] = options[:html_tooltips] if options.key?(:html_tooltips)
  save_options[:sort_labels] = options[:sort_labels] if options.key?(:sort_labels)
  save_options[:rotate_labels] = options[:rotate_labels] if options.key?(:rotate_labels)
  save_options[:label_padding] = options[:label_padding] if options[:label_padding]
  save_options[:label_radius] = options[:label_radius] if options[:label_radius]
  save_options[:label_border] = options[:label_border] if options.key?(:label_border)
  save_options[:label_background] = options[:label_background] if options.key?(:label_background)
  save_options[:initial_arrow_length] = options[:initial_arrow_length] if options[:initial_arrow_length]
  save_options[:initial_arrow_label] = options[:initial_arrow_label] if options.key?(:initial_arrow_label)
  save_options[:final_arrow_length] = options[:final_arrow_length] if options[:final_arrow_length]
  save_options[:final_arrow_label] = options[:final_arrow_label] if options.key?(:final_arrow_label)
  save_options[:show_final_arrows] = options[:show_final_arrows] if options.key?(:show_final_arrows)
  save_options[:scc_groups] = options[:scc_groups] if options.key?(:scc_groups)
  save_options[:fold_groups] = options[:fold_groups] if options.key?(:fold_groups)
  save_options[:highlight_unreachable] = options[:highlight_unreachable] if options.key?(:highlight_unreachable)
  save_options[:unreachable_zone] = options[:unreachable_zone] if options[:unreachable_zone]
  save_options[:highlight_dead_states] = options[:highlight_dead_states] if options.key?(:highlight_dead_states)
  save_options[:highlight_initial_state] = options[:highlight_initial_state] if options.key?(:highlight_initial_state)
  save_options[:highlight_final_states] = options[:highlight_final_states] if options.key?(:highlight_final_states)
  save_options[:highlight_transitions] = options[:highlight_transitions] if options[:highlight_transitions]
  save_options[:loop_position] = options[:loop_position] if options[:loop_position]
end
if %i[png pdf webp].include?(resolved_output_format)
  save_options[:converter] = options[:converter] if options[:converter]
  save_options[:timeout] = options[:timeout] if options[:timeout]
  save_options[:max_output_bytes] = options[:max_output_bytes] if options[:max_output_bytes]
end
save_options[:scale] = options[:scale] if options[:scale] && resolved_output_format == :png
if resolved_output_format == :html
  save_options[:cdn] = options[:cdn] if options[:cdn]
  save_options[:offline] = options[:offline] if options.key?(:offline)
  save_options[:inline_mermaid] = options[:inline_mermaid] if options.key?(:inline_mermaid)
  save_options[:inline_mathjax] = options[:inline_mathjax] if options.key?(:inline_mathjax)
  save_options[:self_contained] = options[:self_contained] if options.key?(:self_contained)
  save_options[:nonce] = options[:nonce] if options[:nonce]
  save_options[:csp] = options[:csp] if options.key?(:csp)
  save_options[:mermaid_sha256] = options[:mermaid_sha256] if options[:mermaid_sha256]
  save_options[:mathjax_sha256] = options[:mathjax_sha256] if options[:mathjax_sha256]
  save_options[:title] = options[:title] if options[:title]
  save_options[:lang] = options[:lang] if options[:lang]
  save_options[:show_source] = options[:show_source] if options.key?(:show_source)
  save_options[:pan_zoom] = options[:pan_zoom] if options.key?(:pan_zoom)
  save_options[:mathjax] = options[:mathjax] if options.key?(:mathjax)
  save_options[:mathjax_cdn] = options[:mathjax_cdn] if options[:mathjax_cdn]
end
if %i[html mermaid plantuml].include?(resolved_output_format)
  save_options[:notes] = options[:notes] if options.key?(:notes)
end
if %i[html mermaid].include?(resolved_output_format)
  save_options[:class_defs] = options[:class_defs] if options.key?(:class_defs)
end
save_options[:rank_constraints] = options[:rank_constraints] if options.key?(:rank_constraints) && resolved_output_format == :dot

begin
  result = automaton.render_result(
    format: resolved_output_format,
    width: options[:width],
    height: options[:height],
    strict_semantics: options[:strict_semantics] || false,
    **save_options
  )
  diagnostics = result.diagnostics.dup
  diagnostics.concat(automaton.validation_diagnostics(profile: :fsm_semantics)) if options[:fail_on_warning]
  visible_diagnostics = diagnostics.select do |diagnostic|
    !diagnostic.code.start_with?('state-clipped-', 'label-') || options[:layout_warnings]
  end
  emit_diagnostics(visible_diagnostics, format: options[:diagnostics] || :text, stream: @stderr) if visible_diagnostics.any?
  if options[:fail_on_warning] && diagnostics.any? { |diagnostic| diagnostic.severity == :warning }
    halt(EXIT_VALIDATION)
  end

  if output_path == '-'
    entry = Graphomaton::EXPORTERS.fetch(resolved_output_format)
    @stdout.binmode if entry.binary && @stdout.respond_to?(:binmode)
    @stdout.write(result.output)
  else
    Graphomaton::AtomicFile.write(
      output_path,
      result.output,
      binary: Graphomaton::EXPORTERS.fetch(resolved_output_format).binary,
      no_clobber: options[:no_clobber]
    )
  end
rescue Graphomaton::SecurityError => e
  report_exception(e)
  halt(EXIT_SECURITY)
rescue Graphomaton::LayoutError => e
  report_exception(e)
  halt(EXIT_LAYOUT)
rescue Graphomaton::Exporters::Png::ConversionError,
       Graphomaton::Exporters::Pdf::ConversionError,
       Graphomaton::Exporters::Webp::ConversionError,
       ArgumentError,
       SystemCallError => e
  report_exception(e)
  halt(EXIT_EXPORT)
end
    end
  end
end
