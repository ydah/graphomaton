# frozen_string_literal: true

require 'json'
require 'open3'
require 'shellwords'
require 'set'
require 'yaml'

require_relative 'graphomaton/atomic_file'
require_relative 'graphomaton/errors'
require_relative 'graphomaton/exporter_registry'
require_relative 'graphomaton/identifier_allocator'
require_relative 'graphomaton/input_policy'
require_relative 'graphomaton/layout/force_tree'
require_relative 'graphomaton/model'
require_relative 'graphomaton/process_runner'
require_relative 'graphomaton/url_policy'
require_relative 'graphomaton/exporters'
require_relative 'graphomaton/version'

class Graphomaton

  class Theme
    def self.default
      Exporters::Svg::THEMES.fetch(Exporters::Svg::DEFAULT_THEME)
    end

    def self.available_names
      Exporters::Svg::THEMES.keys
    end

    def self.normalize(theme, context: 'Graphomaton theme')
      raise ArgumentError, "#{context} must be a Hash" unless theme.is_a?(Hash)

      normalized = theme.transform_keys { |key| key.to_sym }
      unknown = normalized.keys - default.keys
      raise ArgumentError, "Unknown #{context} keys: #{unknown.join(', ')}" unless unknown.empty?

      normalized.each do |key, value|
        validate_value(key, value, context: context)
      end

      default.merge(normalized)
    end

    def self.resolve(theme, context: 'Graphomaton theme', allow_auto: false)
      return normalize(theme, context: context) if theme.is_a?(Hash)

      theme_name = theme.to_s.to_sym
      return default if allow_auto && theme_name == :auto

      Exporters::Svg::THEMES.fetch(theme_name)
    rescue KeyError
      available = available_names
      available = available + [:auto] if allow_auto
      raise ArgumentError, "Unknown #{context}: #{theme.inspect}. Available themes: #{available.join(', ')}"
    end

    def self.gallery_html(title: 'Graphomaton Theme Gallery', themes: Exporters::Svg::THEMES, animated: false)
      cards = themes.map do |name, theme|
        normalized = normalize(theme)
        theme_card(name, normalized)
      end.join("\n")

      <<~HTML
        <!DOCTYPE html>
        <html lang="en">
        <head>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <title>#{escape_html(title)}</title>
          <style>
            body { background: #f8fafc; color: #0f172a; font-family: Georgia, serif; margin: 0; padding: 32px; }
            h1 { font-size: clamp(2rem, 4vw, 4rem); margin: 0 0 24px; }
            .theme-gallery { display: grid; gap: 20px; grid-template-columns: repeat(auto-fit, minmax(260px, 1fr)); }
            .theme-card { background: white; border: 1px solid #e2e8f0; border-radius: 18px; box-shadow: 0 18px 40px rgba(15, 23, 42, 0.08); overflow: hidden; }
            .theme-card h2 { font-size: 1rem; letter-spacing: 0.08em; margin: 0; padding: 16px 18px; text-transform: uppercase; }
            .theme-card svg { display: block; width: 100%; }
            #{theme_gallery_animation_css(animated)}
          </style>
        </head>
        <body>
          <h1>#{escape_html(title)}</h1>
          <div class="theme-gallery">
        #{cards}
          </div>
        </body>
        </html>
      HTML
    end

    def self.save_gallery_html(filename, **options)
      AtomicFile.write(filename, gallery_html(**options))
    end

    def self.theme_card(name, theme)
      background = theme[:background] || '#ffffff'

      <<~HTML
            <article class="theme-card">
              <h2>#{escape_html(name)}</h2>
              <svg viewBox="0 0 260 150" role="img" aria-label="#{escape_html(name)} theme preview" style="background: #{escape_html(background)}">
                <path d="M76 76 C112 32, 148 32, 184 76" fill="none" stroke="#{escape_html(theme[:stroke])}" stroke-width="3" marker-end="url(#arrow-#{escape_html(name)})"/>
                <defs>
                  <marker id="arrow-#{escape_html(name)}" markerWidth="10" markerHeight="6" refX="9" refY="3" orient="auto">
                    <path d="M0 0 L10 3 L0 6 Z" fill="#{escape_html(theme[:stroke])}"/>
                  </marker>
                </defs>
                <circle cx="70" cy="82" r="28" fill="#{escape_html(theme[:state_fill])}" stroke="#{escape_html(theme[:stroke])}" stroke-width="3"/>
                <circle cx="190" cy="82" r="28" fill="#{escape_html(theme[:state_fill])}" stroke="#{escape_html(theme[:stroke])}" stroke-width="3"/>
                <text x="70" y="88" text-anchor="middle" fill="#{escape_html(theme[:state_text])}" font-size="18">A</text>
                <text x="190" y="88" text-anchor="middle" fill="#{escape_html(theme[:state_text])}" font-size="18">B</text>
                <rect x="113" y="42" width="34" height="22" rx="4" fill="#{escape_html(theme[:label_background])}" opacity="#{escape_html(theme[:label_opacity])}"/>
                <text x="130" y="58" text-anchor="middle" fill="#{escape_html(theme[:transition_label])}" font-size="14">a</text>
              </svg>
            </article>
      HTML
    end
    private_class_method :theme_card

    def self.theme_gallery_animation_css(animated)
      return '' unless animated

      <<~CSS
            .theme-card path { animation: graphomaton-gallery-dash 2.4s linear infinite; stroke-dasharray: 12 8; }
            .theme-card circle { animation: graphomaton-gallery-pulse 2.4s ease-in-out infinite; transform-box: fill-box; transform-origin: center; }
            @keyframes graphomaton-gallery-dash {
              to { stroke-dashoffset: -40; }
            }
            @keyframes graphomaton-gallery-pulse {
              0%, 100% { transform: scale(1); }
              50% { transform: scale(1.05); }
            }
            @media (prefers-reduced-motion: reduce) {
              .theme-card path,
              .theme-card circle { animation: none; }
            }
      CSS
    end
    private_class_method :theme_gallery_animation_css

    def self.escape_html(value)
      value.to_s
           .gsub('&', '&amp;')
           .gsub('<', '&lt;')
           .gsub('>', '&gt;')
           .gsub('"', '&quot;')
           .gsub("'", '&#39;')
    end
    private_class_method :escape_html

    def self.validate_value(key, value, context:)
      string = value.to_s
      if string.match?(/[\u0000-\u001f\u007f;{}]/) || string.match?(/url\s*\(/i)
        raise Graphomaton::SecurityError, "Unsafe #{context} value for #{key}: #{value.inspect}"
      end

      return unless key == :label_opacity

      opacity = Float(value)
      return if opacity.finite? && opacity.between?(0.0, 1.0)

      raise ArgumentError
    rescue ArgumentError, TypeError
      raise ArgumentError, "#{context} label_opacity must be between 0 and 1" if key == :label_opacity

      raise
    end
    private_class_method :validate_value
  end

  STATE_RADIUS = 40
  DEFAULT_STATE_RADIUS = STATE_RADIUS
  DEFAULT_PADDING = 80
  DEFAULT_NODE_SPACING = 120
  DEFAULT_RANK_SPACING = 120
  DEFAULT_FORCE_ITERATIONS = 120
  DEFAULT_GRAPHVIZ_COMMAND = 'dot'
  DEFAULT_PRESERVE_MANUAL_POSITIONS = true
  DEFAULT_FIT = :none
  LAYOUT_OPTIONS = %i[linear circle grid layered bfs force graphviz dot manual].freeze
  DIRECTION_OPTIONS = %i[lr tb rl bt].freeze
  FIT_OPTIONS = %i[none contain cover].freeze
  STATE_KIND_OPTIONS = %i[normal choice fork join].freeze
  INITIAL_POSITION_OPTIONS = %i[auto start].freeze
  FINAL_POSITION_OPTIONS = %i[auto end].freeze
  FORMAT_OPTIONS = %i[svg png pdf webp html mermaid mmd dot plantuml puml].freeze
  FORMAT_ALIASES = {
    mmd: :mermaid,
    puml: :plantuml
  }.freeze
  ALL_EXPORT_CAPABILITIES = %i[
    state_style transition_style url tooltip group parent pseudostate bundle line_style
  ].freeze
  EXPORTERS = ExporterRegistry.new.tap do |registry|
    registry.register(:svg, extensions: %w[svg], capabilities: ALL_EXPORT_CAPABILITIES) { Exporters::Svg }
    registry.register(:png, extensions: %w[png], binary: true, capabilities: ALL_EXPORT_CAPABILITIES) { Exporters::Png }
    registry.register(:pdf, extensions: %w[pdf], binary: true, capabilities: ALL_EXPORT_CAPABILITIES) { Exporters::Pdf }
    registry.register(:webp, extensions: %w[webp], binary: true, capabilities: ALL_EXPORT_CAPABILITIES) { Exporters::Webp }
    registry.register(:html, extensions: %w[html], capabilities: %i[group parent pseudostate tooltip]) { Exporters::Mermaid }
    registry.register(:mermaid, aliases: %i[mmd], extensions: %w[mermaid mmd], capabilities: %i[group parent pseudostate tooltip]) { Exporters::Mermaid }
    registry.register(:dot, aliases: %i[gv], extensions: %w[dot gv], capabilities: %i[url tooltip group pseudostate bundle line_style]) { Exporters::Dot }
    registry.register(:plantuml, aliases: %i[puml], extensions: %w[plantuml puml], capabilities: %i[group parent pseudostate tooltip]) { Exporters::Plantuml }
  end
  DEFAULT_INITIAL_POSITION = :auto
  DEFAULT_FINAL_POSITION = :auto
  DEFAULT_EPSILON_LABEL = "\u03b5"
  DEFAULT_MAX_INPUT_BYTES = 10 * 1024 * 1024
  DEFAULT_MAX_STATES = 10_000
  DEFAULT_MAX_TRANSITIONS = 100_000
  DEFAULT_MAX_METADATA_DEPTH = 64
  DEFAULT_MAX_LABEL_LENGTH = 64 * 1024
  DEFAULT_MAX_GROUP_DEPTH = 64
  DEFAULT_MAX_CANVAS_AREA = 100_000_000
  DEFAULT_MAX_LAYOUT_ITERATIONS = 10_000
  FORCE_TREE_THRESHOLD = 128
  VALIDATION_MODES = %i[deferred strict].freeze
  VALIDATION_PROFILES = %i[references fsm_semantics dfa].freeze
  UNSET = Object.new.freeze
  EMPTY_TRANSITIONS = [].freeze
  attr_reader :initial_state, :revision

  def self.png_available?(converter: Exporters::Png::DEFAULT_CONVERTER)
    Exporters::Png.available?(converter: converter)
  end

  def self.pdf_available?(converter: Exporters::Pdf::DEFAULT_CONVERTER)
    Exporters::Pdf.available?(converter: converter)
  end

  def self.webp_available?(converter: Exporters::Webp::DEFAULT_CONVERTER)
    Exporters::Webp.available?(converter: converter)
  end

  def self.register_exporter(name, **options, &loader)
    EXPORTERS.register(name, **options, &loader)
  end

  def self.exporter_capabilities(format)
    EXPORTERS.fetch(format).capabilities
  end

  def self.from_hash(data = nil, max_states: DEFAULT_MAX_STATES, max_transitions: DEFAULT_MAX_TRANSITIONS,
                     max_metadata_depth: DEFAULT_MAX_METADATA_DEPTH, max_label_length: DEFAULT_MAX_LABEL_LENGTH,
                     max_group_depth: DEFAULT_MAX_GROUP_DEPTH, strict_schema: true, **input)
    if data.nil? && !input.empty?
      data = input
    elsif !input.empty?
      raise ArgumentError, "Unknown input keywords: #{input.keys.join(', ')}"
    end
    raise ArgumentError, 'Graphomaton input must be a Hash' unless data.is_a?(Hash)

    enforce_positive_limit(max_metadata_depth, 'max_metadata_depth')
    enforce_positive_limit(max_label_length, 'max_label_length')
    enforce_positive_limit(max_group_depth, 'max_group_depth')

    InputPolicy.known_keys!(data, InputPolicy::TOP_LEVEL_KEYS, context: 'top-level', strict: strict_schema)
    ensure_alias_values_agree!(data, :initial, :initial_state, context: 'top-level initial state')
    ensure_alias_values_agree!(data, :final, :final_states, context: 'top-level final states')
    version = input_value(data, :version)
    raise ArgumentError, "Unsupported Graphomaton schema version: #{version.inspect}" unless version.nil? || version == 1

    automaton = new
    states = state_inputs(input_value(data, :states))
    transitions = transition_inputs(input_value(data, :transitions))
    enforce_collection_limit(states, max_states, 'states')
    enforce_collection_limit(transitions, max_transitions, 'transitions')

    states.each do |state|
      add_state_from_input(
        automaton,
        state,
        max_metadata_depth: max_metadata_depth,
        max_label_length: max_label_length,
        strict_schema: strict_schema
      )
    end

    initial_state = input_value(data, :initial, :initial_state)
    assign_initial_from_input(automaton, initial_state) unless initial_state.nil?

    Array(input_value(data, :final, :final_states)).each do |state|
      automaton.add_final(state)
    end

    transitions.each do |transition|
      add_transition_from_input(
        automaton,
        transition,
        max_metadata_depth: max_metadata_depth,
        max_label_length: max_label_length,
        strict_schema: strict_schema
      )
    end

    enforce_group_depth(automaton, max_group_depth)

    automaton
  end

  def self.from_json(source, max_input_bytes: DEFAULT_MAX_INPUT_BYTES, **limits)
    from_hash(JSON.parse(bounded_source(source, max_input_bytes)), **limits)
  end

  def self.from_yaml(source, aliases: false, max_input_bytes: DEFAULT_MAX_INPUT_BYTES, **limits)
    yaml = YAML.safe_load(bounded_source(source, max_input_bytes), permitted_classes: [Symbol], aliases: aliases)
    from_hash(yaml || {}, **limits)
  end

  def self.theme_from_hash(data)
    raise ArgumentError, 'Graphomaton theme input must be a Hash' unless data.is_a?(Hash)

    theme = input_value(data, :theme) || data
    Theme.normalize(theme, context: 'Graphomaton theme')
  end

  def self.theme_from_json(source, max_input_bytes: DEFAULT_MAX_INPUT_BYTES)
    theme_from_hash(JSON.parse(bounded_source(source, max_input_bytes)))
  end

  def self.theme_from_yaml(source, aliases: false, max_input_bytes: DEFAULT_MAX_INPUT_BYTES)
    yaml = YAML.safe_load(bounded_source(source, max_input_bytes), permitted_classes: [Symbol], aliases: aliases)
    theme_from_hash(yaml || {})
  end

  def self.add_state_from_input(automaton, input, max_metadata_depth:, max_label_length:, strict_schema:)
    unless input.is_a?(Hash)
      raise ArgumentError, 'State input requires a non-nil id' if input.nil?
      raise ArgumentError, "Duplicate state id: #{input.inspect}" if automaton.state_records.key?(input)

      automaton.add_state(input, max_metadata_depth: max_metadata_depth, max_label_length: max_label_length)
      return
    end

    InputPolicy.known_keys!(input, InputPolicy::STATE_KEYS, context: 'state', strict: strict_schema)
    ensure_alias_values_agree!(input, :id, :name, context: 'state id')
    ensure_alias_values_agree!(
      input,
      :final,
      :accepting,
      context: "State #{input_value(input, :id, :name).inspect} final flag"
    )

    name = input_value(input, :id, :name)
    raise ArgumentError, 'State input requires id or name' if name.nil?
    raise ArgumentError, "Duplicate state id: #{name.inspect}" if automaton.state_records.key?(name)

    InputPolicy.boolean!(input_value(input, :initial), context: "State #{name.inspect} initial")
    InputPolicy.boolean!(input_value(input, :final, :accepting), context: "State #{name.inspect} final")
    automaton.add_state(
      name,
      input_value(input, :x),
      input_value(input, :y),
      label: input_value(input, :label),
      style: input_value(input, :style),
      metadata: input_value(input, :metadata),
      shape: input_value(input, :shape),
      kind: input_value(input, :kind),
      max_metadata_depth: max_metadata_depth,
      max_label_length: max_label_length
    )
    assign_initial_from_input(automaton, name) if input_value(input, :initial)
    automaton.add_final(name) if input_value(input, :final, :accepting)
  end
  private_class_method :add_state_from_input

  def self.assign_initial_from_input(automaton, state)
    current = automaton.initial_state
    if !current.nil? && current != state
      raise ArgumentError, "Multiple initial states: #{current.inspect} and #{state.inspect}"
    end

    automaton.set_initial(state)
  end
  private_class_method :assign_initial_from_input

  def self.add_transition_from_input(automaton, input, max_metadata_depth:, max_label_length:, strict_schema:)
    if input.is_a?(Array)
      unless input.length == 3 && input.none?(&:nil?)
        raise ArgumentError, 'Transition Array input requires exactly from, to, and label'
      end

      from, to, label = input
      label = structured_label_from_input(label)
      automaton.add_transition(from, to, label, max_metadata_depth: max_metadata_depth, max_label_length: max_label_length)
      return
    end

    raise ArgumentError, 'Transition input must be a Hash or Array' unless input.is_a?(Hash)

    InputPolicy.known_keys!(input, InputPolicy::TRANSITION_KEYS, context: 'transition', strict: strict_schema)

    from = input_value(input, :from)
    to = input_value(input, :to)
    label = structured_label_from_input(input_value(input, :label))
    raise ArgumentError, 'Transition input requires from, to, and label' if from.nil? || to.nil? || label.nil?

    automaton.add_transition(
      from,
      to,
      label,
      style: input_value(input, :style),
      metadata: input_value(input, :metadata),
      line_style: input_value(input, :line_style),
      max_metadata_depth: max_metadata_depth,
      max_label_length: max_label_length
    )
  end
  private_class_method :add_transition_from_input

  def self.structured_label_from_input(label)
    return label unless label.is_a?(Hash)

    type = input_value(label, :type, :kind)
    raise ArgumentError, 'Structured transition label requires type or kind' unless type

    case type.to_sym
    when :text
      Label.text(input_value(label, :value, :text))
    when :symbols
      Label.symbols(*Array(input_value(label, :value, :symbols)))
    when :epsilon
      Label.epsilon(input_value(label, :value) || DEFAULT_EPSILON_LABEL)
    when :uml
      value = input_value(label, :value)
      value = label unless value.is_a?(Hash)
      Label.uml(
        event: input_value(value, :event),
        guard: input_value(value, :guard),
        action: input_value(value, :action)
      )
    else
      raise ArgumentError, "Unknown label type: #{type.inspect}"
    end
  end
  private_class_method :structured_label_from_input

  def self.state_inputs(input)
    return [] if input.nil?
    return input if input.is_a?(Array)
    raise ArgumentError, 'States input must be an Array or Hash' unless input.is_a?(Hash)

    input.map do |name, attributes|
      next name if attributes.nil?
      raise ArgumentError, "State #{name.inspect} attributes must be a Hash" unless attributes.is_a?(Hash)

      ensure_alias_values_agree!(attributes, :id, :name, context: "State #{name.inspect} id")
      explicit_name = input_value(attributes, :id, :name)
      if !explicit_name.nil? && explicit_name != name
        raise ArgumentError, "State map key #{name.inspect} conflicts with id #{explicit_name.inspect}"
      end

      explicit_name.nil? ? attributes.merge(id: name) : attributes
    end
  end
  private_class_method :state_inputs

  def self.ensure_alias_values_agree!(hash, *keys, context:)
    values = keys.filter_map do |key|
      if hash.key?(key)
        [key, hash[key]]
      elsif hash.key?(key.to_s)
        [key, hash[key.to_s]]
      end
    end
    return if values.size < 2 || values.map(&:last).uniq.size == 1

    details = values.map { |key, value| "#{key}=#{value.inspect}" }.join(', ')
    raise ArgumentError, "Conflicting #{context}: #{details}"
  end
  private_class_method :ensure_alias_values_agree!

  def self.transition_inputs(input)
    return [] if input.nil?
    raise ArgumentError, 'Transitions input must be an Array' unless input.is_a?(Array)

    input
  end
  private_class_method :transition_inputs

  def self.bounded_source(source, max_input_bytes)
    enforce_positive_limit(max_input_bytes, 'max_input_bytes')
    text = source.respond_to?(:read) ? read_bounded_io(source, max_input_bytes) : source.to_s
    if text.bytesize > max_input_bytes
      raise ArgumentError, "Graphomaton input exceeds max_input_bytes (#{max_input_bytes})"
    end

    text
  end
  private_class_method :bounded_source

  def self.read_bounded_io(source, max_input_bytes)
    output = String.new(encoding: Encoding::BINARY)
    while output.bytesize <= max_input_bytes
      chunk = source.read([16 * 1024, max_input_bytes + 1 - output.bytesize].min)
      break if chunk.nil? || chunk.empty?

      output << chunk
    end
    output
  end
  private_class_method :read_bounded_io

  def self.enforce_group_depth(automaton, maximum)
    enforce_positive_limit(maximum, 'max_group_depth')
    automaton.state_records.each_key do |state|
      depth = 0
      current = state
      seen = {}
      while current
        break if seen[current]

        seen[current] = true
        metadata = automaton.state_records[current]&.fetch(:metadata, nil)
        current = metadata.is_a?(Hash) ? input_value(metadata, :parent) : nil
        depth += 1 if current
        raise ArgumentError, "State hierarchy exceeds max_group_depth (#{maximum})" if depth > maximum
      end
    end
  end
  private_class_method :enforce_group_depth

  def self.enforce_collection_limit(collection, limit, name)
    enforce_positive_limit(limit, "max_#{name}")
    return if collection.size <= limit

    raise ArgumentError, "Graphomaton input exceeds max_#{name} (#{limit})"
  end
  private_class_method :enforce_collection_limit

  def self.enforce_positive_limit(limit, name)
    return if limit.is_a?(Integer) && limit.positive?

    raise ArgumentError, "#{name} must be a positive Integer"
  end
  private_class_method :enforce_positive_limit

  def self.input_value(hash, *keys)
    keys.each do |key|
      return hash[key] if hash.key?(key)
      return hash[key.to_s] if hash.key?(key.to_s)
    end

    nil
  end
  private_class_method :input_value

  def initialize(validation: :deferred)
    @validation_mode = validation.to_sym
    unless VALIDATION_MODES.include?(@validation_mode)
      raise ArgumentError, "Unknown validation mode: #{validation.inspect}. Available modes: #{VALIDATION_MODES.join(', ')}"
    end

    @states = {}
    @transitions = []
    @initial_state = nil
    @final_states = []
    @final_state_set = Set.new
    @state_positions = {}
    @manual_states = {}
    @revision = 0
    @next_transition_id = 0
    @layout_cache = {}
  end

  def states
    immutable_snapshot(@states.transform_values(&:to_h))
  end

  def transitions
    immutable_snapshot(@transitions.map(&:to_h))
  end

  def final_states
    immutable_snapshot(@final_states)
  end

  def state_records
    @states.dup.freeze
  end

  def transition_records
    @transitions.dup.freeze
  end

  def add_state(name, x = nil, y = nil, label: nil, style: nil, metadata: nil, shape: nil, kind: nil,
                max_metadata_depth: DEFAULT_MAX_METADATA_DEPTH, max_label_length: DEFAULT_MAX_LABEL_LENGTH)
    InputPolicy.identifier!(name, context: 'State id')
    label = label.to_s if label.is_a?(Label)
    InputPolicy.label!(label, context: "State #{name.inspect} label", max_bytes: max_label_length)
    InputPolicy.mapping!(style, context: "State #{name.inspect} style")
    InputPolicy.mapping!(metadata, context: "State #{name.inspect} metadata")
    if metadata
      InputPolicy.nested_depth!(
        metadata,
        maximum: max_metadata_depth,
        context: "State #{name.inspect} metadata",
        max_string_bytes: max_label_length
      )
    end
    raise ArgumentError, "Duplicate state id: #{name.inspect}" if @states.key?(name)
    if x.nil? != y.nil?
      raise ArgumentError, 'State coordinates require both x and y'
    end
    unless x.nil?
      validate_finite_number!(x, 'state x coordinate')
      validate_finite_number!(y, 'state y coordinate')
    end

    stable_name = immutable_copy(name)
    @manual_states[stable_name] = !x.nil? && !y.nil?
    @states[stable_name] = State.new(
      id: stable_name,
      x: x,
      y: y,
      label: immutable_copy(label),
      style: immutable_copy(style),
      metadata: immutable_copy(metadata),
      shape: immutable_copy(shape),
      kind: resolve_state_kind(kind)
    )
    graph_changed!
    self
  end

  def upsert_state(name, x = UNSET, y = UNSET, **attributes)
    unless @states.key?(name)
      new_x = x.equal?(UNSET) ? nil : x
      new_y = y.equal?(UNSET) ? nil : y
      return add_state(name, new_x, new_y, **attributes)
    end

    return update_state(name, **attributes) if x.equal?(UNSET) && y.equal?(UNSET)
    if x.equal?(UNSET) || y.equal?(UNSET)
      raise ArgumentError, 'State coordinates require both x and y'
    end

    update_state(name, x: x, y: y, **attributes)
  end

  def update_state(name, **attributes)
    state = @states.fetch(name) { raise ArgumentError, "State is not defined: #{name.inspect}" }
    allowed = %i[x y label style metadata shape kind]
    unknown = attributes.keys - allowed
    raise ArgumentError, "Unknown state attributes: #{unknown.join(', ')}" unless unknown.empty?
    if attributes.key?(:x) != attributes.key?(:y)
      raise ArgumentError, 'State coordinates require both x and y'
    end

    x = attributes.fetch(:x, state.x)
    y = attributes.fetch(:y, state.y)
    if x.nil? != y.nil?
      raise ArgumentError, 'State coordinates require both x and y'
    end
    unless x.nil?
      validate_finite_number!(x, 'state x coordinate')
      validate_finite_number!(y, 'state y coordinate')
    end
    label = attributes.fetch(:label, state.label)
    label = label.to_s if label.is_a?(Label)
    style = attributes.fetch(:style, state.style)
    metadata = attributes.fetch(:metadata, state.metadata)
    InputPolicy.label!(label, context: "State #{name.inspect} label", max_bytes: DEFAULT_MAX_LABEL_LENGTH)
    InputPolicy.mapping!(style, context: "State #{name.inspect} style")
    InputPolicy.mapping!(metadata, context: "State #{name.inspect} metadata")
    if metadata
      InputPolicy.nested_depth!(
        metadata,
        maximum: DEFAULT_MAX_METADATA_DEPTH,
        context: "State #{name.inspect} metadata",
        max_string_bytes: DEFAULT_MAX_LABEL_LENGTH
      )
    end

    updated_state = State.new(
      id: state.id,
      x: x,
      y: y,
      label: immutable_copy(label),
      style: immutable_copy(style),
      metadata: immutable_copy(metadata),
      shape: immutable_copy(attributes.fetch(:shape, state.shape)),
      kind: resolve_state_kind(attributes.fetch(:kind, state.kind))
    )
    return self if updated_state == state

    @states[name] = updated_state
    @manual_states[name] = !x.nil? && !y.nil?
    graph_changed!
    self
  end

  def remove_state(name, cascade: false)
    raise ArgumentError, "State is not defined: #{name.inspect}" unless @states.key?(name)

    connected = @transitions.select { |transition| transition.from == name || transition.to == name }
    if connected.any? && !cascade
      raise ArgumentError, "State #{name.inspect} has transitions; pass cascade: true to remove them"
    end

    @states.delete(name)
    @manual_states.delete(name)
    @state_positions.delete(name)
    @transitions -= connected
    @initial_state = nil if @initial_state == name
    if @final_state_set.delete?(name)
      @final_states.delete(name)
    end
    graph_changed!
    self
  end

  def add_transition(from, to, label, style: nil, metadata: nil, line_style: nil,
                     epsilon_label: DEFAULT_EPSILON_LABEL, sort_labels: false,
                     max_metadata_depth: DEFAULT_MAX_METADATA_DEPTH, max_label_length: DEFAULT_MAX_LABEL_LENGTH)
    InputPolicy.identifier!(from, context: 'Transition source')
    InputPolicy.identifier!(to, context: 'Transition target')
    raise ArgumentError, 'Transition label cannot be nil' if label.nil?
    labels = label.is_a?(Array) ? label : [label]
    raise ArgumentError, 'Transition labels cannot be empty' if labels.empty?
    raise ArgumentError, 'Transition labels cannot contain nil' if labels.any?(&:nil?)
    labels.each do |item|
      InputPolicy.label!(item, context: 'Transition label', max_bytes: max_label_length)
    end
    InputPolicy.mapping!(style, context: 'Transition style')
    InputPolicy.mapping!(metadata, context: 'Transition metadata')
    if metadata
      InputPolicy.nested_depth!(
        metadata,
        maximum: max_metadata_depth,
        context: 'Transition metadata',
        max_string_bytes: max_label_length
      )
    end
    if @validation_mode == :strict
      raise ValidationError, "Transition source #{from.inspect} is not defined" unless @states.key?(from)
      raise ValidationError, "Transition target #{to.inspect} is not defined" unless @states.key?(to)
    end
    @next_transition_id += 1
    @transitions << Transition.new(
      id: @next_transition_id,
      from: immutable_copy(from),
      to: immutable_copy(to),
      label: immutable_copy(normalize_transition_label(label, epsilon_label: epsilon_label, sort_labels: sort_labels)),
      style: immutable_copy(style),
      metadata: immutable_copy(metadata),
      line_style: immutable_copy(line_style)
    )
    graph_changed!
    self
  end

  def update_transition(identifier, **attributes)
    index = transition_index(identifier)
    transition = @transitions.fetch(index)
    allowed = %i[from to label style metadata line_style]
    unknown = attributes.keys - allowed
    raise ArgumentError, "Unknown transition attributes: #{unknown.join(', ')}" unless unknown.empty?

    from = attributes.fetch(:from, transition.from)
    to = attributes.fetch(:to, transition.to)
    label = attributes.fetch(:label, transition.label)
    InputPolicy.identifier!(from, context: 'Transition source')
    InputPolicy.identifier!(to, context: 'Transition target')
    raise ArgumentError, 'Transition label cannot be nil' if label.nil?
    labels = label.is_a?(Array) ? label : [label]
    raise ArgumentError, 'Transition labels cannot be empty' if labels.empty?
    raise ArgumentError, 'Transition labels cannot contain nil' if labels.any?(&:nil?)
    labels.each do |item|
      InputPolicy.label!(item, context: 'Transition label', max_bytes: DEFAULT_MAX_LABEL_LENGTH)
    end
    if @validation_mode == :strict
      raise ValidationError, "Transition source #{from.inspect} is not defined" unless @states.key?(from)
      raise ValidationError, "Transition target #{to.inspect} is not defined" unless @states.key?(to)
    end
    metadata = attributes.fetch(:metadata, transition.metadata)
    style = attributes.fetch(:style, transition.style)
    InputPolicy.mapping!(style, context: 'Transition style')
    InputPolicy.mapping!(metadata, context: 'Transition metadata')
    InputPolicy.nested_depth!(metadata, maximum: DEFAULT_MAX_METADATA_DEPTH, context: 'Transition metadata') if metadata

    updated_transition = Transition.new(
      id: transition.id,
      from: immutable_copy(from),
      to: immutable_copy(to),
      label: immutable_copy(normalize_transition_label(label)),
      style: immutable_copy(style),
      metadata: immutable_copy(metadata),
      line_style: immutable_copy(attributes.fetch(:line_style, transition.line_style))
    )
    return self if updated_transition == transition

    @transitions[index] = updated_transition
    graph_changed!
    self
  end

  def remove_transition(identifier)
    @transitions.delete_at(transition_index(identifier))
    graph_changed!
    self
  end

  def set_initial(state)
    InputPolicy.identifier!(state, context: 'Initial state id')
    raise ValidationError, "Initial state #{state.inspect} is not defined" if @validation_mode == :strict && !@states.key?(state)

    stable_state = immutable_copy(state)
    return self if @initial_state == stable_state

    @initial_state = stable_state
    graph_changed!
    self
  end

  def clear_initial
    return self if @initial_state.nil?

    @initial_state = nil
    graph_changed!
    self
  end

  def add_final(state)
    InputPolicy.identifier!(state, context: 'Final state id')
    raise ValidationError, "Final state #{state.inspect} is not defined" if @validation_mode == :strict && !@states.key?(state)
    return self if @final_state_set.include?(state)

    stable_state = immutable_copy(state)
    @final_states << stable_state
    @final_state_set << stable_state
    graph_changed!
    self
  end

  def remove_final(state)
    return self unless @final_state_set.delete?(state)

    @final_states.delete(state)
    graph_changed!
    self
  end

  def validation_diagnostics(profile: :references)
    profiles = Array(profile).map(&:to_sym)
    profiles = profiles.flat_map { |name| name == :all ? VALIDATION_PROFILES : name }.uniq
    unknown = profiles - VALIDATION_PROFILES
    unless unknown.empty?
      raise ArgumentError, "Unknown validation profiles: #{unknown.join(', ')}. Available profiles: #{VALIDATION_PROFILES.join(', ')}"
    end
    diagnostics = reference_diagnostics if profiles.include?(:references)
    diagnostics ||= []
    diagnostics.concat(fsm_semantic_diagnostics) if profiles.include?(:fsm_semantics)
    diagnostics.concat(dfa_diagnostics) if profiles.include?(:dfa)
    diagnostics.freeze
  end

  def validation_errors(profile: :references)
    validation_diagnostics(profile: profile)
      .select { |diagnostic| diagnostic.severity == :error }
      .map(&:message)
  end

  def analysis_warnings
    validation_diagnostics(profile: :fsm_semantics)
      .select { |diagnostic| diagnostic.severity == :warning }
      .map(&:message)
  end

  def valid?(profile: :references)
    validation_errors(profile: profile).empty?
  end

  def validate!(profile: :references)
    errors = validation_errors(profile: profile)
    return true if errors.empty?

    raise ValidationError, errors.join("\n")
  end

  def reachable_states
    layered_distances.keys
  end

  def reachable_from(state)
    raise ArgumentError, "State is not defined: #{state.inspect}" unless @states.key?(state)

    ensure_analysis_index!
    visited = { state => true }
    queue = [state]
    head = 0
    while head < queue.length
      current = queue[head]
      head += 1
      @outgoing_by_state[current].each do |transition|
        target = transition.to
        next if visited[target]

        visited[target] = true
        queue << target
      end
    end
    ordered_state_names.select { |name| visited[name] }
  end

  alias reachable_from_initial reachable_states

  def graph_roots
    ensure_analysis_index!
    ordered_state_names.select { |state| @incoming_by_state[state].empty? }
  end

  def weakly_connected_components
    weak_components(ordered_state_names)
  end

  def unreachable_states
    @states.keys - reachable_states
  end

  def states_reaching_final
    defined_final_states = @final_states.select { |state| @states.key?(state) }
    return [] if defined_final_states.empty?

    ensure_analysis_index!

    reachable = defined_final_states.to_h { |state| [state, true] }
    queue = reachable.keys
    head = 0
    while head < queue.length
      state = queue[head]
      head += 1
      @incoming_by_state[state].each do |transition|
        previous = transition.from
        next if reachable[previous]

        reachable[previous] = true
        queue << previous
      end
    end

    ordered_state_names.select { |state| reachable[state] }
  end

  def dead_states
    reaching_final = states_reaching_final
    return [] if reaching_final.empty?

    @states.keys - reaching_final
  end

  def live_states
    states_reaching_final
  end

  def trap_states
    self_loop_traps
  end

  def self_loop_traps
    ensure_analysis_index!
    ordered_state_names.select do |state|
      outgoing = @outgoing_by_state[state]
      next false if outgoing.empty?

      outgoing.all? { |transition| transition.to == state }
    end
  end

  def sink_states
    ensure_analysis_index!
    ordered_state_names.select { |state| @outgoing_by_state[state].empty? }
  end

  def bottom_sccs
    ensure_analysis_index!
    strongly_connected_components.select do |component|
      members = component.to_set
      component.all? { |state| @outgoing_by_state[state].all? { |transition| members.include?(transition.to) } }
    end
  end

  def strongly_connected_components
    ensure_analysis_index!
    adjacency = @outgoing_by_state.transform_values { |transitions| transitions.map(&:to) }
    reverse_adjacency = @incoming_by_state.transform_values { |transitions| transitions.map(&:from) }

    visited = {}
    finish_order = []
    @states.each_key do |state|
      next if visited[state]

      visited[state] = true
      stack = [[state, 0]]
      until stack.empty?
        current, next_index = stack.last
        if next_index < adjacency[current].length
          target = adjacency[current][next_index]
          stack.last[1] += 1
          next if visited[target]

          visited[target] = true
          stack << [target, 0]
        else
          finish_order << current
          stack.pop
        end
      end
    end

    assigned = {}
    finish_order.reverse_each.filter_map do |state|
      next if assigned[state]

      component = []
      stack = [state]
      assigned[state] = true
      until stack.empty?
        current = stack.pop
        component << current
        reverse_adjacency[current].reverse_each do |target|
          next if assigned[target]

          assigned[target] = true
          stack << target
        end
      end
      component
    end
  end

  def layout_warnings(width = 800, height = 600, layout: :linear, direction: :lr,
                      state_radius: DEFAULT_STATE_RADIUS, padding: DEFAULT_PADDING,
                      node_spacing: DEFAULT_NODE_SPACING, rank_spacing: DEFAULT_RANK_SPACING,
                      force_iterations: DEFAULT_FORCE_ITERATIONS, layout_seed: nil,
                      graphviz_command: DEFAULT_GRAPHVIZ_COMMAND,
                      initial_position: DEFAULT_INITIAL_POSITION, final_position: DEFAULT_FINAL_POSITION,
                      preserve_manual_positions: DEFAULT_PRESERVE_MANUAL_POSITIONS,
                      fit: DEFAULT_FIT)
    positions = layout_positions(
      width,
      height,
      layout: layout,
      direction: direction,
      state_radius: state_radius,
      padding: padding,
      node_spacing: node_spacing,
      rank_spacing: rank_spacing,
      force_iterations: force_iterations,
      layout_seed: layout_seed,
      graphviz_command: graphviz_command,
      initial_position: initial_position,
      final_position: final_position,
      preserve_manual_positions: preserve_manual_positions,
      fit: fit
    )

    layout_diagnostics_for(positions, width, height, state_radius).map(&:message)
  end

  def layout_diagnostics_for(positions, width, height, state_radius)
    radius = state_radius.to_f
    positions.each_with_object([]) do |(name, position), diagnostics|
      x = position[:x].to_f
      y = position[:y].to_f
      if x - radius < 0 || x + radius > width.to_f
        diagnostics << Diagnostic.new(
          code: 'state-clipped-horizontal',
          severity: :warning,
          path: ['states', name, 'x'],
          message: "State #{name.inspect} may be clipped horizontally",
          hint: 'Increase the canvas width or use fit: :contain'
        )
      end
      if y - radius < 0 || y + radius > height.to_f
        diagnostics << Diagnostic.new(
          code: 'state-clipped-vertical',
          severity: :warning,
          path: ['states', name, 'y'],
          message: "State #{name.inspect} may be clipped vertically",
          hint: 'Increase the canvas height or use fit: :contain'
        )
      end
    end.freeze
  end

  def layout_positions(width = 800, height = 600, layout: :linear, direction: :lr,
                      state_radius: DEFAULT_STATE_RADIUS, padding: DEFAULT_PADDING,
                      node_spacing: DEFAULT_NODE_SPACING, rank_spacing: DEFAULT_RANK_SPACING,
                      force_iterations: DEFAULT_FORCE_ITERATIONS, layout_seed: nil,
                      graphviz_command: DEFAULT_GRAPHVIZ_COMMAND,
                      initial_position: DEFAULT_INITIAL_POSITION, final_position: DEFAULT_FINAL_POSITION,
                      preserve_manual_positions: DEFAULT_PRESERVE_MANUAL_POSITIONS,
                      fit: DEFAULT_FIT)
    validate_finite_number!(width, 'width', positive: true)
    validate_finite_number!(height, 'height', positive: true)
    if width.to_f * height.to_f > DEFAULT_MAX_CANVAS_AREA
      raise ArgumentError, "canvas area exceeds max_canvas_area (#{DEFAULT_MAX_CANVAS_AREA})"
    end
    validate_finite_number!(state_radius, 'state_radius', positive: true)
    validate_finite_number!(padding, 'padding', nonnegative: true)
    validate_finite_number!(node_spacing, 'node_spacing', nonnegative: true)
    validate_finite_number!(rank_spacing, 'rank_spacing', nonnegative: true)
    unless force_iterations.is_a?(Integer) && force_iterations >= 0
      raise ArgumentError, 'force_iterations must be a non-negative Integer'
    end
    if force_iterations > DEFAULT_MAX_LAYOUT_ITERATIONS
      raise ArgumentError, "force_iterations exceeds max_layout_iterations (#{DEFAULT_MAX_LAYOUT_ITERATIONS})"
    end
    unless layout_seed.nil? || layout_seed.is_a?(Integer)
      raise ArgumentError, 'layout_seed must be an Integer or nil'
    end

    return {} if @states.empty?

    resolved_layout = resolve_layout(layout)
    resolved_direction = resolve_direction(direction)
    resolved_fit = resolve_fit(fit)
    resolved_initial_position = resolve_initial_position(initial_position)
    resolved_final_position = resolve_final_position(final_position)
    resolved_padding = [padding.to_f, 0].max
    resolved_node_spacing = [node_spacing.to_f, (state_radius * 2.5)].max
    resolved_rank_spacing = [rank_spacing.to_f, (state_radius * 2.5)].max
    effective_preserve_manual_positions = preserve_manual_positions || resolved_layout == :manual
    cache_key = [
      width.to_f, height.to_f, resolved_layout, resolved_direction, state_radius.to_f, resolved_padding,
      resolved_node_spacing, resolved_rank_spacing, force_iterations, layout_seed,
      Array(graphviz_command), resolved_initial_position, resolved_final_position,
      effective_preserve_manual_positions, resolved_fit
    ].freeze
    if (cached = @layout_cache[cache_key])
      positions = deep_copy(cached)
      @state_positions = positions
      return positions
    end
    ordered_states = ordered_state_names

    manual_positions = {}
    auto_states = []

    ordered_states.each do |name|
      state = @states[name]
      if effective_preserve_manual_positions && manual_position?(name)
        validate_finite_number!(state[:x], "state #{name.inspect} x coordinate")
        validate_finite_number!(state[:y], "state #{name.inspect} y coordinate")
        manual_positions[name] = { x: state[:x], y: state[:y] }
      else
        auto_states << name
      end
    end

    auto_states = arrange_auto_states(
      auto_states,
      initial_position: resolved_initial_position,
      final_position: resolved_final_position
    )

    auto_positions = case resolved_layout
                    when :linear
                      layout_linear_positions(auto_states, width, height, resolved_direction, state_radius,
                                             resolved_padding, resolved_node_spacing)
                    when :circle
                      layout_circle_positions(auto_states, width, height, resolved_direction, state_radius, resolved_padding)
                    when :grid
                      layout_grid_positions(auto_states, width, height, resolved_direction, state_radius,
                                           resolved_padding, resolved_node_spacing)
                    when :layered, :bfs
                      layout_layered_positions(auto_states, width, height, resolved_direction, state_radius,
                                              resolved_padding, resolved_node_spacing, resolved_rank_spacing,
                                              final_position: resolved_final_position)
                    when :manual
                      if auto_states.empty?
                        {}
                      else
                        raise ArgumentError, "Manual layout requires explicit coordinates for: #{auto_states.join(', ')}"
                      end
                    when :force
                      layout_force_positions(
                        auto_states,
                        width,
                        height,
                        resolved_direction,
                        state_radius,
                        resolved_padding,
                        resolved_node_spacing,
                        force_iterations,
                        layout_seed,
                        fixed_positions: manual_positions
                      )
                    when :graphviz, :dot
                      layout_graphviz_positions(
                        auto_states,
                        width,
                        height,
                        resolved_direction,
                        state_radius,
                        resolved_padding,
                        command: graphviz_command
                      )
                    else
                      raise ArgumentError, "Unknown SVG layout: #{layout.inspect}. Available layouts: #{LAYOUT_OPTIONS.join(', ')}"
                    end

    if resolved_layout != :force
      auto_positions = avoid_fixed_position_collisions(
        auto_positions,
        manual_positions,
        width,
        height,
        state_radius,
        resolved_padding,
        resolved_node_spacing,
        resolved_direction
      )
    end
    positions = manual_positions.merge(auto_positions)
    positions = fit_positions(positions, width, height, state_radius, resolved_padding, resolved_fit) unless resolved_fit == :none
    @state_positions = positions
    @layout_cache.shift if @layout_cache.size >= 16
    @layout_cache[cache_key] = immutable_copy(positions)
    positions
  end

  def ordered_state_names
    ordered_states = []
    ordered_states << @initial_state if @initial_state && @states[@initial_state]

    @states.each_key do |name|
      ordered_states << name unless ordered_states.include?(name)
    end

    ordered_states
  end

  def auto_layout(width = 800, height = 600, layout: :linear, direction: :lr,
                 state_radius: DEFAULT_STATE_RADIUS, padding: DEFAULT_PADDING,
                 node_spacing: DEFAULT_NODE_SPACING, rank_spacing: DEFAULT_RANK_SPACING,
                 force_iterations: DEFAULT_FORCE_ITERATIONS, layout_seed: nil,
                 graphviz_command: DEFAULT_GRAPHVIZ_COMMAND,
                 initial_position: DEFAULT_INITIAL_POSITION, final_position: DEFAULT_FINAL_POSITION,
                 preserve_manual_positions: DEFAULT_PRESERVE_MANUAL_POSITIONS,
                 fit: DEFAULT_FIT)
    return self if @states.empty?

    resolved_layout = resolve_layout(layout)
    effective_preserve_manual_positions = preserve_manual_positions || resolved_layout == :manual

    layout_positions(
      width,
      height,
      layout: resolved_layout,
      direction: direction,
      state_radius: state_radius,
      padding: padding,
      node_spacing: node_spacing,
      rank_spacing: rank_spacing,
      force_iterations: force_iterations,
      layout_seed: layout_seed,
      graphviz_command: graphviz_command,
      initial_position: initial_position,
      final_position: final_position,
      preserve_manual_positions: effective_preserve_manual_positions,
      fit: fit
    ).each do |name, position|
      state = @states[name]
      next if effective_preserve_manual_positions && manual_position?(name) && resolve_fit(fit) == :none

      @states[name] = State.new(
        id: state.id,
        x: position[:x],
        y: position[:y],
        label: state.label,
        style: state.style,
        metadata: state.metadata,
        shape: state.shape,
        kind: state.kind
      )
    end
    graph_changed!
    self
  end

  def layout_linear_positions(auto_states, width, height, direction, state_radius = DEFAULT_STATE_RADIUS,
                             padding = DEFAULT_PADDING, node_spacing = DEFAULT_NODE_SPACING)
    return {} if auto_states.empty?

    margin = [padding, state_radius + 20].max
    available_x = [width - (2 * margin), 0].max.to_f
    available_y = [height - (2 * margin), 0].max.to_f
    count = auto_states.size
    horizontal_step = count > 1 ? [available_x / (count - 1), node_spacing].max : 0
    vertical_step = count > 1 ? [available_y / (count - 1), node_spacing].max : 0

    positions = {}
    auto_states.each_with_index do |name, index|
      positions[name] = layout_linear_position(
        index,
        count,
        width.to_f,
        height.to_f,
        margin,
        horizontal_step,
        vertical_step,
        direction
      )
    end

    positions
  end

  def layout_circle_positions(auto_states, width, height, direction, state_radius = DEFAULT_STATE_RADIUS,
                             padding = DEFAULT_PADDING)
    return {} if auto_states.empty?

    count = auto_states.size
    ordered = (direction == :rl || direction == :bt) ? auto_states.reverse : auto_states
    center_x = width / 2.0
    center_y = height / 2.0
    margin = [padding, state_radius + 20].max
    max_radius = [width, height].min / 2.0 - margin - state_radius
    minimum_radius = if count > 1
                       (state_radius * 2.0) / (2.0 * Math.sin(Math::PI / count))
                     else
                       0.0
                     end
    radius = [max_radius, minimum_radius, state_radius + 20].max
    angle_start = case direction
                  when :tb then 0.0
                  when :bt then Math::PI
                  else
                    -Math::PI / 2.0
                  end
    angle_step = (2 * Math::PI) / count

    positions = {}
    ordered.each_with_index do |name, index|
      angle = angle_start + (angle_step * index)
      positions[name] = {
        x: center_x + (radius * Math.cos(angle)),
        y: center_y + (radius * Math.sin(angle))
      }
    end

    positions
  end

  def layout_grid_positions(auto_states, width, height, direction, state_radius = DEFAULT_STATE_RADIUS,
                           padding = DEFAULT_PADDING, node_spacing = DEFAULT_NODE_SPACING)
    return {} if auto_states.empty?

    count = auto_states.size
    columns = Math.sqrt(count).ceil
    rows = [(count.to_f / columns).ceil, 1].max.to_i

    margin = [padding, state_radius + 20].max
    available_x = [width - (2 * margin), 0].max.to_f
    available_y = [height - (2 * margin), 0].max.to_f
    horizontal_step = columns > 1 ? [available_x / (columns - 1), node_spacing].max : 0
    vertical_step = rows > 1 ? [available_y / (rows - 1), node_spacing].max : 0

    positions = {}
    auto_states.each_with_index do |name, index|
      if direction == :tb || direction == :bt
        row = index % rows
        column = index / rows
        y = if direction == :tb
              margin + (row * vertical_step)
            else
              height - margin - (row * vertical_step)
            end
      else
        row = index / columns
        column = index % columns
        y = margin + (row * vertical_step)
      end

      x = if direction == :rl
            width - margin - (column * horizontal_step)
          else
            margin + (column * horizontal_step)
          end

      positions[name] = { x: x, y: y }
    end

    positions
  end

  def layout_layered_positions(auto_states, width, height, direction, state_radius = DEFAULT_STATE_RADIUS,
                              padding = DEFAULT_PADDING, node_spacing = DEFAULT_NODE_SPACING,
                              rank_spacing = DEFAULT_RANK_SPACING, final_position: DEFAULT_FINAL_POSITION)
    return {} if auto_states.empty?

    layer_groups = layout_layered_groups(auto_states, final_position: final_position)
    return layout_linear_positions(auto_states, width, height, direction, state_radius, padding, node_spacing) if layer_groups.empty?

    margin = [padding, state_radius + 20].max
    available_x = [width - (2 * margin), 0].max.to_f
    available_y = [height - (2 * margin), 0].max.to_f
    layers = layer_groups.keys
    layer_count = layers.size

    positions = {}
    layers = layers.sort_by do |depth|
      depth.to_i
    end
    layer_groups = crossing_reduced_layer_groups(layer_groups, layers)

    layers.each_with_index do |layer, layer_index|
      states = layer_groups[layer] || []
      state_count = states.size
      next if state_count.zero?

      if direction == :lr || direction == :rl
        x = if layer_count > 1
              margin + (rank_spacing * layer_index)
            else
              width / 2.0
            end
        x = width - margin - ((rank_spacing * layer_index)) if direction == :rl && layer_count > 1
        y_step = state_count > 1 ? [available_y / (state_count + 1), node_spacing].max : 0

        states.each_with_index do |name, state_index|
          y = if state_count > 1
                margin + ((state_index + 1) * y_step)
              else
                height / 2.0
              end
          positions[name] = { x: x, y: y }
        end
      else
        y = if layer_count > 1
              margin + (rank_spacing * layer_index)
            else
              height / 2.0
            end
        y = height - margin - (rank_spacing * layer_index) if direction == :bt && layer_count > 1
        x_step = state_count > 1 ? [available_x / (state_count + 1), node_spacing].max : 0

        states.each_with_index do |name, state_index|
          x = if state_count > 1
                margin + ((state_index + 1) * x_step)
              else
                width / 2.0
              end
          positions[name] = { x: x, y: y }
        end
      end
    end

    positions
  end

  def crossing_reduced_layer_groups(layer_groups, layers)
    ordered = {}
    previous_order = nil

    layers.each do |layer|
      states = layer_groups[layer] || []
      ordered[layer] = if previous_order
                         order_layer_by_neighbor_barycenter(states, previous_order, incoming: true)
                       else
                         states
                       end
      previous_order = ordered[layer]
    end

    next_order = nil
    layers.reverse_each do |layer|
      states = ordered[layer] || []
      ordered[layer] = order_layer_by_neighbor_barycenter(states, next_order, incoming: false) if next_order
      next_order = ordered[layer]
    end

    ordered
  end

  def order_layer_by_neighbor_barycenter(states, adjacent_order, incoming:)
    adjacent_index = adjacent_order.each_with_index.to_h
    original_index = states.each_with_index.to_h

    states.sort_by do |name|
      neighbor_positions = layer_neighbor_positions(name, adjacent_index, incoming: incoming)
      if neighbor_positions.empty?
        [1, original_index[name], 0.0]
      else
        average = neighbor_positions.sum.to_f / neighbor_positions.size
        [0, average, original_index[name]]
      end
    end
  end

  def layer_neighbor_positions(name, adjacent_index, incoming:)
    ensure_analysis_index!
    transitions = incoming ? @incoming_by_state[name] : @outgoing_by_state[name]
    transitions.filter_map do |transition|
      neighbor = incoming ? transition.from : transition.to
      adjacent_index[neighbor] if neighbor && adjacent_index.key?(neighbor)
    end
  end

  def layout_layered_groups(auto_states, final_position: DEFAULT_FINAL_POSITION)
    return {} if auto_states.empty?
    distances = layered_distances
    return {} if distances.empty?

    resolved_final_position = resolve_final_position(final_position)
    groups = Hash.new { |hash, key| hash[key] = [] }
    auto_states.each do |name|
      next unless distances.key?(name)

      groups[distances[name]] << name
    end

    unreachable_states = auto_states.reject { |name| distances.key?(name) }
    if unreachable_states.any?
      max_depth = distances.values.max || 0
      weak_components(unreachable_states).each_with_index do |component, index|
        groups[max_depth + 1 + index].concat(component)
      end
    end

    return groups unless resolved_final_position == :end

    final_states = auto_states.select { |name| @final_states.include?(name) }
    return groups if final_states.empty?

    groups.each_value do |states|
      states.reject! { |name| @final_states.include?(name) }
    end

    final_layer = (groups.keys.max || 0) + 1
    groups[final_layer] = []
    auto_states.each do |name|
      groups[final_layer] << name if @final_states.include?(name)
    end

    groups
  end

  def weak_components(states)
    return [] if states.empty?

    ensure_analysis_index!
    remaining = states.to_h { |state| [state, true] }

    components = []
    while (seed = remaining.keys.first)
      stack = [seed]
      component = []

      until stack.empty?
        state = stack.pop
        next unless remaining.delete(state)

        component << state
        @undirected_neighbors[state].each do |next_state|
          next unless remaining.key?(next_state)

          stack << next_state
        end
      end

      components << component
    end

    components
  end

  def layered_distances
    return {} unless @initial_state && @states[@initial_state]

    ensure_analysis_index!

    distances = {}
    queue = [@initial_state]
    distances[@initial_state] = 0

    head = 0
    while head < queue.length
      current = queue[head]
      head += 1
      @outgoing_by_state[current].each do |transition|
        next_state = transition.to
        next if distances.key?(next_state)

        distances[next_state] = distances[current] + 1
        queue << next_state
      end
    end

    distances
  end

  def layout_force_positions(auto_states, width, height, direction, state_radius = DEFAULT_STATE_RADIUS,
                            padding = DEFAULT_PADDING, node_spacing = DEFAULT_NODE_SPACING,
                            force_iterations = DEFAULT_FORCE_ITERATIONS, layout_seed = nil, fixed_positions: {})
    return {} if auto_states.empty?

    iterations = [force_iterations.to_i, 0].max
    return {} if width <= 0 || height <= 0

    positions = {}
    count = auto_states.size
    center_x = width / 2.0
    center_y = height / 2.0
    radius = [width, height].min / 4.0
    radius = [radius, node_spacing].min if radius > 0

    auto_states.each_with_index do |name, index|
      if count == 1
        x = center_x
        y = center_y
      else
        offset_ratio = count > 1 ? (index.to_f / (count - 1)) : 0.5

        case direction
        when :lr
          x = padding + (offset_ratio * (width - (2 * padding)))
          y = center_y
        when :rl
          x = width - padding - (offset_ratio * (width - (2 * padding)))
          y = center_y
        when :tb
          x = center_x
          y = padding + (offset_ratio * (height - (2 * padding)))
        when :bt
          x = center_x
          y = height - padding - (offset_ratio * (height - (2 * padding)))
        else
          angle = (2 * Math::PI * index) / count
          x = center_x + (Math.cos(angle) * radius)
          y = center_y + (Math.sin(angle) * radius)
        end
      end

      positions[name] = { x: x.to_f, y: y.to_f }
    end

    return positions if iterations.zero?

    rng = layout_seed ? Random.new(layout_seed) : nil

    if rng
      positions.each_value do |position|
        position[:x] += (rng.rand - 0.5) * 10
        position[:y] += (rng.rand - 0.5) * 10
      end
    end

    manual_positions = fixed_positions

    k = [node_spacing, 1.0].max
    attraction_coeff = 0.01
    repulsion_coeff = (k * k)
    max_displacement = [width, height].min * 0.05

    iterations.times do |step|
      forces = auto_states.to_h do |name|
        [name, { x: 0.0, y: 0.0 }]
      end

      if positions.size + manual_positions.size >= FORCE_TREE_THRESHOLD
        force_tree = Layout::ForceTree.new(manual_positions.merge(positions))
        positions.each do |name, current|
          force_x, force_y = force_tree.force_on(name, current, repulsion_coeff) do |left, right|
            deterministic_separation_delta(left, right)
          end
          forces[name][:x] += force_x
          forces[name][:y] += force_y
        end
      else
        accumulate_exact_repulsion!(forces, positions, manual_positions, repulsion_coeff)
      end

      @transitions.each do |transition|
        from = transition[:from]
        to = transition[:to]

        from_point = positions[from] || manual_positions[from]
        to_point = positions[to] || manual_positions[to]
        next unless from_point && to_point

        delta_x = to_point[:x] - from_point[:x]
        delta_y = to_point[:y] - from_point[:y]
        distance = Math.sqrt((delta_x * delta_x) + (delta_y * delta_y))
        distance = 1.0 if distance <= 0.0

        force = (distance * distance) / k
        nx = delta_x / distance
        ny = delta_y / distance

        if positions.key?(from)
          forces[from][:x] += nx * force * attraction_coeff
          forces[from][:y] += ny * force * attraction_coeff
        end

        if positions.key?(to)
          forces[to][:x] -= nx * force * attraction_coeff
          forces[to][:y] -= ny * force * attraction_coeff
        end
      end

      damping = 1.0 - (step.to_f / (iterations + 1).to_f)
      max_move = max_displacement * damping
      largest_movement = 0.0

      positions.each_key do |name|
        current = positions[name]
        force = forces[name]
        next unless current && force

        next_x = current[:x] + force[:x].clamp(-max_move, max_move)
        next_y = current[:y] + force[:y].clamp(-max_move, max_move)

        boundary_margin = padding + state_radius
        next_x = [[next_x, boundary_margin].max, width - boundary_margin].min if width >= boundary_margin * 2
        next_y = [[next_y, boundary_margin].max, height - boundary_margin].min if height >= boundary_margin * 2

        movement = Math.hypot(next_x - current[:x], next_y - current[:y])
        largest_movement = movement if movement > largest_movement

        current[:x] = next_x
        current[:y] = next_y
      end
      break if largest_movement < 0.01
    end

    positions
  end

  def accumulate_exact_repulsion!(forces, positions, manual_positions, coefficient)
    positions.to_a.combination(2) do |(name_a, a), (name_b, b)|
      delta_x = a[:x] - b[:x]
      delta_y = a[:y] - b[:y]
      if delta_x.zero? && delta_y.zero?
        delta_x, delta_y = deterministic_separation_delta(name_a, name_b)
      end
      force_x, force_y = repulsion_vector(delta_x, delta_y, coefficient)
      forces[name_a][:x] += force_x
      forces[name_a][:y] += force_y
      forces[name_b][:x] -= force_x
      forces[name_b][:y] -= force_y
    end

    manual_positions.each do |fixed_name, fixed|
      positions.each do |name, current|
        delta_x = current[:x] - fixed[:x].to_f
        delta_y = current[:y] - fixed[:y].to_f
        if delta_x.zero? && delta_y.zero?
          delta_x, delta_y = deterministic_separation_delta(name, fixed_name)
        end
        force_x, force_y = repulsion_vector(delta_x, delta_y, coefficient)
        forces[name][:x] += force_x
        forces[name][:y] += force_y
      end
    end
  end

  def repulsion_vector(delta_x, delta_y, coefficient)
    distance = Math.hypot(delta_x, delta_y)
    return [0.0, 0.0] unless distance.positive?

    force = coefficient / distance
    [(delta_x / distance) * force, (delta_y / distance) * force]
  end
  private :accumulate_exact_repulsion!, :repulsion_vector

  def deterministic_separation_delta(left, right)
    seed = "#{left.class.name}:#{left.inspect}|#{right.class.name}:#{right.inspect}".each_byte.reduce(2_166_136_261) do |hash, byte|
      ((hash ^ byte) * 16_777_619) & 0xffffffff
    end
    angle = (seed % 360) * Math::PI / 180.0
    [Math.cos(angle) * 0.01, Math.sin(angle) * 0.01]
  end
  private :deterministic_separation_delta

  def layout_graphviz_positions(auto_states, width, height, direction, state_radius = DEFAULT_STATE_RADIUS,
                               padding = DEFAULT_PADDING, command: DEFAULT_GRAPHVIZ_COMMAND)
    return {} if auto_states.empty?

    state_ids = graphviz_layout_state_ids(auto_states)
    stdout, stderr, status = ProcessRunner.capture3(
      *graphviz_command_args(command),
      '-Tplain',
      stdin_data: graphviz_layout_dot(auto_states, direction, state_ids)
    )

    unless status.success?
      message = stderr.to_s.strip
      message = 'dot exited without a diagnostic' if message.empty?
      raise LayoutError, "Graphviz layout failed: #{message}"
    end

    normalize_graphviz_positions(
      parse_graphviz_plain_positions(stdout, auto_states, state_ids),
      width,
      height,
      state_radius,
      padding
    )
  rescue Errno::ENOENT
    raise LayoutError, "Graphviz layout requires the `#{Array(command).join(' ')}` command"
  rescue ProcessRunner::Error => e
    raise LayoutError, "Graphviz layout failed: #{e.message}"
  rescue ArgumentError => e
    raise LayoutError, "Graphviz layout failed: #{e.message}"
  end

  def graphviz_layout_state_ids(auto_states)
    allocator = IdentifierAllocator.new
    auto_states.to_h do |name|
      preferred = name.to_s if name.to_s.match?(/\A[A-Za-z_][A-Za-z0-9_]*\z/)
      [name, allocator.allocate([:state, name], preferred: preferred, prefix: 'state')]
    end
  end

  def graphviz_layout_dot(auto_states, direction, state_ids)
    included = auto_states.to_h { |name| [name, true] }
    lines = [
      'digraph graphomaton_layout {',
      "    rankdir=#{graphviz_rankdir(direction)};",
      '    node [shape=circle];'
    ]

    auto_states.each do |name|
      lines << "    \"#{state_ids.fetch(name)}\";"
    end

    @transitions.each do |transition|
      from = transition[:from]
      to = transition[:to]
      next unless included[from] && included[to]

      lines << "    \"#{state_ids.fetch(from)}\" -> \"#{state_ids.fetch(to)}\";"
    end

    lines << '}'
    lines.join("\n")
  end

  def graphviz_command_args(command)
    args = command.is_a?(Array) ? command.map(&:to_s) : Shellwords.split(command.to_s)
    raise ArgumentError, 'Graphviz command cannot be empty' if args.empty?

    args
  end

  def graphviz_rankdir(direction)
    {
      lr: 'LR',
      rl: 'RL',
      tb: 'TB',
      bt: 'BT'
    }.fetch(direction)
  end

  def parse_graphviz_plain_positions(output, expected_states, state_ids)
    positions = {}

    output.each_line do |line|
      tokens = Shellwords.split(line)
      next unless tokens.first == 'node' && tokens.size >= 4

      positions[tokens[1]] = {
        x: Float(tokens[2]),
        y: Float(tokens[3])
      }
    rescue ArgumentError
      next
    end

    missing = expected_states.reject { |name| positions.key?(state_ids.fetch(name)) }
    unless missing.empty?
      raise ArgumentError, "Graphviz layout did not return positions for: #{missing.join(', ')}"
    end

    expected_states.to_h { |name| [name, positions.fetch(state_ids.fetch(name))] }
  end

  def normalize_graphviz_positions(raw_positions, width, height, state_radius, padding)
    return {} if raw_positions.empty?

    canvas_width = width.to_f
    canvas_height = height.to_f
    margin = [padding.to_f, state_radius.to_f + 20].max
    available_x = [canvas_width - (2 * margin), 0].max
    available_y = [canvas_height - (2 * margin), 0].max
    xs = raw_positions.values.map { |position| position[:x].to_f }
    ys = raw_positions.values.map { |position| position[:y].to_f }
    min_x, max_x = xs.minmax
    min_y, max_y = ys.minmax
    span_x = max_x - min_x
    span_y = max_y - min_y

    if span_x <= 0.0 && span_y <= 0.0
      return raw_positions.to_h do |name, _position|
        [name, { x: canvas_width / 2.0, y: canvas_height / 2.0 }]
      end
    end

    scale_candidates = []
    scale_candidates << (available_x / span_x) if span_x.positive?
    scale_candidates << (available_y / span_y) if span_y.positive?
    scale = scale_candidates.min || 1.0
    graph_width = span_x * scale
    graph_height = span_y * scale
    offset_x = margin + ((available_x - graph_width) / 2.0)
    offset_y = margin + ((available_y - graph_height) / 2.0)

    raw_positions.to_h do |name, position|
      x = if span_x.positive?
            offset_x + ((position[:x].to_f - min_x) * scale)
          else
            canvas_width / 2.0
          end
      y = if span_y.positive?
            offset_y + ((max_y - position[:y].to_f) * scale)
          else
            canvas_height / 2.0
          end

      [name, { x: x, y: y }]
    end
  end

  def count_parallel_transitions(from, to)
    ensure_analysis_index!
    @transitions_by_undirected_pair.fetch(Set[from, to].freeze, EMPTY_TRANSITIONS).size
  end

  def get_transition_index(from, to, label)
    ensure_analysis_index!
    transitions = @transitions_by_undirected_pair.fetch(Set[from, to].freeze, EMPTY_TRANSITIONS)
    transitions.index { |transition| transition.from == from && transition.to == to && transition.label == label } || transitions.size
  end

  def outgoing_by_state
    ensure_analysis_index!
    @outgoing_by_state.transform_values { |transitions| transitions.map(&:to_h).freeze }.freeze
  end

  def incoming_by_state
    ensure_analysis_index!
    @incoming_by_state.transform_values { |transitions| transitions.map(&:to_h).freeze }.freeze
  end

  def transitions_by_pair
    ensure_analysis_index!
    @transitions_by_directed_pair.transform_values { |transitions| transitions.map(&:to_h).freeze }.freeze
  end

  def to_h
    output = {
      version: 1,
      states: @states.values.map do |state|
        serialized = { id: state.id }
        serialized[:x] = state.x unless state.x.nil?
        serialized[:y] = state.y unless state.y.nil?
        serialized[:label] = state.label unless state.label.nil?
        serialized[:style] = state.style unless state.style.nil?
        serialized[:metadata] = state.metadata unless state.metadata.nil?
        serialized[:shape] = state.shape unless state.shape.nil?
        serialized[:kind] = state.kind unless state.kind.nil?
        serialized
      end,
      transitions: @transitions.map do |transition|
        serialized = transition.to_h
        serialized[:label] = transition.label.to_h if transition.label.is_a?(Label)
        serialized
      end
    }
    output[:initial] = @initial_state unless @initial_state.nil?
    output[:final] = @final_states unless @final_states.empty?
    immutable_snapshot(output)
  end

  def to_json(*arguments)
    JSON.generate(to_h, *arguments)
  end

  def to_yaml(**options)
    to_h.to_yaml(**options)
  end

  def ==(other)
    other.is_a?(Graphomaton) && to_h == other.to_h
  end

  def write(io, format: :svg, width: 800, height: 600, **options)
    resolved = resolve_format(format)
    output = render(format: resolved, width: width, height: height, **options)
    io.binmode if io.respond_to?(:binmode) && self.class::EXPORTERS.fetch(resolved).binary
    io.write(output)
  end

  def semantic_diagnostics(format)
    resolved = resolve_format(format)
    capabilities = self.class.exporter_capabilities(resolved)
    ExporterCapabilities.losses_for(self, capabilities).map do |feature|
      Diagnostic.new(
        code: 'unsupported-export-feature',
        severity: :warning,
        path: ['export', resolved.to_s],
        message: "#{resolved} output does not preserve #{feature}",
        hint: 'Choose SVG or remove the unsupported feature.'
      )
    end.freeze
  end

  def render(format: :svg, width: 800, height: 600, strict_semantics: false, **options)
    resolved_format = resolve_format(format)
    losses = semantic_diagnostics(resolved_format)
    if strict_semantics && losses.any?
      raise ExportError, losses.map(&:message).join("\n")
    end

    case resolved_format
    when :svg
      to_svg(width, height, **options)
    when :png
      to_png(width, height, **options)
    when :pdf
      to_pdf(width, height, **options)
    when :webp
      to_webp(width, height, **options)
    when :html
      to_html(**options)
    when :mermaid
      to_mermaid(**options)
    when :dot
      to_dot(**options)
    when :plantuml
      to_plantuml(**options)
    else
      exporter = self.class::EXPORTERS.fetch(resolved_format).exporter.new(self)
      exporter.export(width, height, **options)
    end
  end

  def render_with(options)
    raise ArgumentError, 'options must be a Graphomaton::RenderOptions' unless options.is_a?(RenderOptions)

    render(format: options.format, width: options.width, height: options.height, **options.options)
  end

  def render_result(format: :svg, width: 800, height: 600, strict_semantics: false, **options)
    resolved = resolve_format(format)
    return Exporters::Svg.new(self).export_result(width, height, **options) if resolved == :svg
    return Exporters::Png.new(self).export_result(width, height, **options) if resolved == :png
    return Exporters::Pdf.new(self).export_result(width, height, **options) if resolved == :pdf
    return Exporters::Webp.new(self).export_result(width, height, **options) if resolved == :webp

    output = render(
      format: resolved,
      width: width,
      height: height,
      strict_semantics: strict_semantics,
      **options
    )
    RenderResult.new(
      output: output,
      diagnostics: semantic_diagnostics(resolved),
      bounds: nil,
      layout: nil
    )
  end

  def save(filename, format: nil, width: 800, height: 600, **options)
    resolved_format = resolve_format(format || File.extname(filename).delete_prefix('.'))
    output = render(format: resolved_format, width: width, height: height, **options)
    AtomicFile.write(filename, output, binary: self.class::EXPORTERS.fetch(resolved_format).binary)
  end

  def to_svg(width = 800, height = 600, theme: Exporters::Svg::DEFAULT_THEME,
             layout: :linear, direction: :lr, responsive: false, state_radius: DEFAULT_STATE_RADIUS,
             auto_state_radius: Exporters::Svg::DEFAULT_AUTO_STATE_RADIUS,
             min_state_radius: Exporters::Svg::DEFAULT_MIN_STATE_RADIUS,
             max_state_radius: Exporters::Svg::DEFAULT_MAX_STATE_RADIUS,
             state_shape: Exporters::Svg::DEFAULT_STATE_SHAPE,
             state_stroke_width: Exporters::Svg::DEFAULT_STATE_STROKE_WIDTH,
             transition_stroke_width: Exporters::Svg::DEFAULT_TRANSITION_STROKE_WIDTH,
             padding: DEFAULT_PADDING, node_spacing: DEFAULT_NODE_SPACING, rank_spacing: DEFAULT_RANK_SPACING,
             force_iterations: DEFAULT_FORCE_ITERATIONS, layout_seed: nil, auto_size: false,
             graphviz_command: DEFAULT_GRAPHVIZ_COMMAND,
             auto_density_spacing: Exporters::Svg::DEFAULT_AUTO_DENSITY_SPACING,
             arrow_size: Exporters::Svg::DEFAULT_ARROW_SIZE,
             arrow_shape: Exporters::Svg::DEFAULT_ARROW_SHAPE,
             initial_arrow_length: Exporters::Svg::DEFAULT_INITIAL_ARROW_LENGTH,
             initial_arrow_label: Exporters::Svg::DEFAULT_INITIAL_ARROW_LABEL,
             final_arrow_length: Exporters::Svg::DEFAULT_FINAL_ARROW_LENGTH,
             final_arrow_label: Exporters::Svg::DEFAULT_FINAL_ARROW_LABEL,
             initial_position: DEFAULT_INITIAL_POSITION, final_position: DEFAULT_FINAL_POSITION,
             merge_parallel_transitions: true, wrap: Exporters::Svg::DEFAULT_WRAP,
             max_transition_label_width: Exporters::Svg::DEFAULT_MAX_LABEL_WIDTH, state_wrap: false,
             max_state_label_width: Exporters::Svg::DEFAULT_MAX_STATE_LABEL_WIDTH,
             sort_labels: Exporters::Svg::DEFAULT_SORT_LABELS,
             label_tooltips: Exporters::Svg::DEFAULT_LABEL_TOOLTIPS,
             html_tooltips: Exporters::Svg::DEFAULT_HTML_TOOLTIPS,
             font_family: Exporters::Svg::DEFAULT_FONT_FAMILY,
             state_font_weight: Exporters::Svg::DEFAULT_STATE_FONT_WEIGHT,
             transition_font_weight: Exporters::Svg::DEFAULT_TRANSITION_FONT_WEIGHT,
             label_background: Exporters::Svg::DEFAULT_LABEL_BACKGROUND,
             label_border: Exporters::Svg::DEFAULT_LABEL_BORDER,
             label_padding: Exporters::Svg::DEFAULT_LABEL_PADDING,
             label_radius: Exporters::Svg::DEFAULT_LABEL_RADIUS,
             rotate_labels: Exporters::Svg::DEFAULT_ROTATE_LABELS,
             highlight_unreachable: false,
             highlight_dead_states: Exporters::Svg::DEFAULT_HIGHLIGHT_DEAD_STATES,
             highlight_initial_state: Exporters::Svg::DEFAULT_HIGHLIGHT_INITIAL_STATE,
             highlight_final_states: Exporters::Svg::DEFAULT_HIGHLIGHT_FINAL_STATES,
             highlight_transitions: Exporters::Svg::DEFAULT_HIGHLIGHT_TRANSITIONS,
             unreachable_zone: Exporters::Svg::DEFAULT_UNREACHABLE_ZONE,
             xml_declaration: Exporters::Svg::DEFAULT_XML_DECLARATION,
             css_variables: Exporters::Svg::DEFAULT_CSS_VARIABLES,
             embed_styles: Exporters::Svg::DEFAULT_EMBED_STYLES,
             pretty: Exporters::Svg::DEFAULT_PRETTY,
             minify: Exporters::Svg::DEFAULT_MINIFY,
             state_effect: Exporters::Svg::DEFAULT_STATE_EFFECT,
             loop_position: Exporters::Svg::DEFAULT_LOOP_POSITION,
             edge_style: Exporters::Svg::DEFAULT_EDGE_STYLE,
             show_final_arrows: Exporters::Svg::DEFAULT_SHOW_FINAL_ARROWS,
             scc_groups: Exporters::Svg::DEFAULT_SCC_GROUPS,
             fold_groups: Exporters::Svg::DEFAULT_FOLD_GROUPS,
             preserve_manual_positions: DEFAULT_PRESERVE_MANUAL_POSITIONS,
             fit: DEFAULT_FIT,
             title: nil, description: nil, svg_id: nil)
    Exporters::Svg.new(self).export(
      width,
      height,
      theme: theme,
      layout: layout,
      direction: direction,
      responsive: responsive,
      state_radius: state_radius,
      auto_state_radius: auto_state_radius,
      min_state_radius: min_state_radius,
      max_state_radius: max_state_radius,
      state_shape: state_shape,
      state_stroke_width: state_stroke_width,
      transition_stroke_width: transition_stroke_width,
      padding: padding,
      node_spacing: node_spacing,
      rank_spacing: rank_spacing,
      force_iterations: force_iterations,
      layout_seed: layout_seed,
      graphviz_command: graphviz_command,
      auto_size: auto_size,
      auto_density_spacing: auto_density_spacing,
      arrow_size: arrow_size,
      arrow_shape: arrow_shape,
      initial_arrow_length: initial_arrow_length,
      initial_arrow_label: initial_arrow_label,
      final_arrow_length: final_arrow_length,
      final_arrow_label: final_arrow_label,
      initial_position: initial_position,
      final_position: final_position,
      merge_parallel_transitions: merge_parallel_transitions,
      label_background: label_background,
      label_border: label_border,
      label_padding: label_padding,
      label_radius: label_radius,
      rotate_labels: rotate_labels,
      highlight_unreachable: highlight_unreachable,
      highlight_dead_states: highlight_dead_states,
      highlight_initial_state: highlight_initial_state,
      highlight_final_states: highlight_final_states,
      highlight_transitions: highlight_transitions,
      unreachable_zone: unreachable_zone,
      xml_declaration: xml_declaration,
      css_variables: css_variables,
      embed_styles: embed_styles,
      pretty: pretty,
      minify: minify,
      state_effect: state_effect,
      loop_position: loop_position,
      edge_style: edge_style,
      show_final_arrows: show_final_arrows,
      scc_groups: scc_groups,
      fold_groups: fold_groups,
      preserve_manual_positions: preserve_manual_positions,
      fit: fit,
      wrap: wrap,
      max_transition_label_width: max_transition_label_width,
      state_wrap: state_wrap,
      max_state_label_width: max_state_label_width,
      sort_labels: sort_labels,
      label_tooltips: label_tooltips,
      html_tooltips: html_tooltips,
      font_family: font_family,
      state_font_weight: state_font_weight,
      transition_font_weight: transition_font_weight,
      title: title,
      description: description,
      svg_id: svg_id
    )
  end

  def save_svg(filename, width = 800, height = 600, theme: Exporters::Svg::DEFAULT_THEME,
               layout: :linear, direction: :lr, responsive: false, state_radius: DEFAULT_STATE_RADIUS,
               auto_state_radius: Exporters::Svg::DEFAULT_AUTO_STATE_RADIUS,
               min_state_radius: Exporters::Svg::DEFAULT_MIN_STATE_RADIUS,
               max_state_radius: Exporters::Svg::DEFAULT_MAX_STATE_RADIUS,
               state_shape: Exporters::Svg::DEFAULT_STATE_SHAPE,
               state_stroke_width: Exporters::Svg::DEFAULT_STATE_STROKE_WIDTH,
               transition_stroke_width: Exporters::Svg::DEFAULT_TRANSITION_STROKE_WIDTH,
               padding: DEFAULT_PADDING, node_spacing: DEFAULT_NODE_SPACING, rank_spacing: DEFAULT_RANK_SPACING,
               force_iterations: DEFAULT_FORCE_ITERATIONS, layout_seed: nil, auto_size: false,
               graphviz_command: DEFAULT_GRAPHVIZ_COMMAND,
               auto_density_spacing: Exporters::Svg::DEFAULT_AUTO_DENSITY_SPACING,
               arrow_size: Exporters::Svg::DEFAULT_ARROW_SIZE,
               arrow_shape: Exporters::Svg::DEFAULT_ARROW_SHAPE,
               initial_arrow_length: Exporters::Svg::DEFAULT_INITIAL_ARROW_LENGTH,
               initial_arrow_label: Exporters::Svg::DEFAULT_INITIAL_ARROW_LABEL,
               final_arrow_length: Exporters::Svg::DEFAULT_FINAL_ARROW_LENGTH,
               final_arrow_label: Exporters::Svg::DEFAULT_FINAL_ARROW_LABEL,
               initial_position: DEFAULT_INITIAL_POSITION, final_position: DEFAULT_FINAL_POSITION,
               merge_parallel_transitions: true, wrap: Exporters::Svg::DEFAULT_WRAP,
               max_transition_label_width: Exporters::Svg::DEFAULT_MAX_LABEL_WIDTH, state_wrap: false,
               max_state_label_width: Exporters::Svg::DEFAULT_MAX_STATE_LABEL_WIDTH,
               sort_labels: Exporters::Svg::DEFAULT_SORT_LABELS,
               label_tooltips: Exporters::Svg::DEFAULT_LABEL_TOOLTIPS,
               html_tooltips: Exporters::Svg::DEFAULT_HTML_TOOLTIPS,
               font_family: Exporters::Svg::DEFAULT_FONT_FAMILY,
               state_font_weight: Exporters::Svg::DEFAULT_STATE_FONT_WEIGHT,
               transition_font_weight: Exporters::Svg::DEFAULT_TRANSITION_FONT_WEIGHT,
               label_background: Exporters::Svg::DEFAULT_LABEL_BACKGROUND,
               label_border: Exporters::Svg::DEFAULT_LABEL_BORDER,
               label_padding: Exporters::Svg::DEFAULT_LABEL_PADDING,
               label_radius: Exporters::Svg::DEFAULT_LABEL_RADIUS,
               rotate_labels: Exporters::Svg::DEFAULT_ROTATE_LABELS,
               highlight_unreachable: false,
               highlight_dead_states: Exporters::Svg::DEFAULT_HIGHLIGHT_DEAD_STATES,
               highlight_initial_state: Exporters::Svg::DEFAULT_HIGHLIGHT_INITIAL_STATE,
               highlight_final_states: Exporters::Svg::DEFAULT_HIGHLIGHT_FINAL_STATES,
               highlight_transitions: Exporters::Svg::DEFAULT_HIGHLIGHT_TRANSITIONS,
               unreachable_zone: Exporters::Svg::DEFAULT_UNREACHABLE_ZONE,
               xml_declaration: Exporters::Svg::DEFAULT_XML_DECLARATION,
               css_variables: Exporters::Svg::DEFAULT_CSS_VARIABLES,
               embed_styles: Exporters::Svg::DEFAULT_EMBED_STYLES,
               pretty: Exporters::Svg::DEFAULT_PRETTY,
               minify: Exporters::Svg::DEFAULT_MINIFY,
               state_effect: Exporters::Svg::DEFAULT_STATE_EFFECT,
               loop_position: Exporters::Svg::DEFAULT_LOOP_POSITION,
               edge_style: Exporters::Svg::DEFAULT_EDGE_STYLE,
               show_final_arrows: Exporters::Svg::DEFAULT_SHOW_FINAL_ARROWS,
               scc_groups: Exporters::Svg::DEFAULT_SCC_GROUPS,
               fold_groups: Exporters::Svg::DEFAULT_FOLD_GROUPS,
               preserve_manual_positions: DEFAULT_PRESERVE_MANUAL_POSITIONS,
               fit: DEFAULT_FIT,
               title: nil, description: nil, svg_id: nil)
    AtomicFile.write(
      filename,
      to_svg(
        width,
        height,
        theme: theme,
        layout: layout,
        direction: direction,
        responsive: responsive,
        state_radius: state_radius,
        auto_state_radius: auto_state_radius,
        min_state_radius: min_state_radius,
        max_state_radius: max_state_radius,
        state_shape: state_shape,
        state_stroke_width: state_stroke_width,
        transition_stroke_width: transition_stroke_width,
        padding: padding,
        node_spacing: node_spacing,
        rank_spacing: rank_spacing,
        force_iterations: force_iterations,
        layout_seed: layout_seed,
        graphviz_command: graphviz_command,
        auto_size: auto_size,
        auto_density_spacing: auto_density_spacing,
        arrow_size: arrow_size,
        arrow_shape: arrow_shape,
        initial_arrow_length: initial_arrow_length,
        initial_arrow_label: initial_arrow_label,
        final_arrow_length: final_arrow_length,
        final_arrow_label: final_arrow_label,
        initial_position: initial_position,
        final_position: final_position,
        merge_parallel_transitions: merge_parallel_transitions,
        label_background: label_background,
        label_border: label_border,
        label_padding: label_padding,
        label_radius: label_radius,
        rotate_labels: rotate_labels,
        highlight_unreachable: highlight_unreachable,
        highlight_dead_states: highlight_dead_states,
        highlight_initial_state: highlight_initial_state,
        highlight_final_states: highlight_final_states,
        highlight_transitions: highlight_transitions,
        unreachable_zone: unreachable_zone,
        xml_declaration: xml_declaration,
        css_variables: css_variables,
        embed_styles: embed_styles,
        pretty: pretty,
        minify: minify,
        state_effect: state_effect,
        loop_position: loop_position,
        edge_style: edge_style,
        show_final_arrows: show_final_arrows,
        scc_groups: scc_groups,
        fold_groups: fold_groups,
        preserve_manual_positions: preserve_manual_positions,
        fit: fit,
        wrap: wrap,
        max_transition_label_width: max_transition_label_width,
        state_wrap: state_wrap,
        max_state_label_width: max_state_label_width,
        sort_labels: sort_labels,
        label_tooltips: label_tooltips,
        html_tooltips: html_tooltips,
        font_family: font_family,
        state_font_weight: state_font_weight,
        transition_font_weight: transition_font_weight,
        title: title,
        description: description,
        svg_id: svg_id
      )
    )
  end

  def to_png(width = 800, height = 600, theme: Exporters::Svg::DEFAULT_THEME,
             scale: Exporters::Png::DEFAULT_SCALE, converter: Exporters::Png::DEFAULT_CONVERTER, **svg_options)
    Exporters::Png.new(self).export(width, height, theme: theme, scale: scale, converter: converter, **svg_options)
  end

  def save_png(filename, width = 800, height = 600, theme: Exporters::Svg::DEFAULT_THEME,
               scale: Exporters::Png::DEFAULT_SCALE, converter: Exporters::Png::DEFAULT_CONVERTER, **svg_options)
    AtomicFile.write(filename, to_png(width, height, theme: theme, scale: scale, converter: converter, **svg_options), binary: true)
  end

  def to_pdf(width = 800, height = 600, theme: Exporters::Svg::DEFAULT_THEME,
             converter: Exporters::Pdf::DEFAULT_CONVERTER, **svg_options)
    Exporters::Pdf.new(self).export(width, height, theme: theme, converter: converter, **svg_options)
  end

  def save_pdf(filename, width = 800, height = 600, theme: Exporters::Svg::DEFAULT_THEME,
               converter: Exporters::Pdf::DEFAULT_CONVERTER, **svg_options)
    AtomicFile.write(filename, to_pdf(width, height, theme: theme, converter: converter, **svg_options), binary: true)
  end

  def to_webp(width = 800, height = 600, theme: Exporters::Svg::DEFAULT_THEME,
              converter: Exporters::Webp::DEFAULT_CONVERTER, **svg_options)
    Exporters::Webp.new(self).export(width, height, theme: theme, converter: converter, **svg_options)
  end

  def save_webp(filename, width = 800, height = 600, theme: Exporters::Svg::DEFAULT_THEME,
                converter: Exporters::Webp::DEFAULT_CONVERTER, **svg_options)
    AtomicFile.write(filename, to_webp(width, height, theme: theme, converter: converter, **svg_options), binary: true)
  end

  def to_mermaid(direction: Exporters::Mermaid::DEFAULT_DIRECTION, notes: Exporters::Mermaid::DEFAULT_NOTES,
                 class_defs: Exporters::Mermaid::DEFAULT_CLASS_DEFS)
    Exporters::Mermaid.new(self, direction: direction, notes: notes, class_defs: class_defs).export
  end

  def to_html(direction: Exporters::Mermaid::DEFAULT_DIRECTION, theme: Exporters::Mermaid::DEFAULT_THEME,
              cdn: Exporters::Mermaid::DEFAULT_CDN, inline_mermaid: false, offline: false, title: nil,
              lang: Exporters::Mermaid::DEFAULT_LANG, show_source: Exporters::Mermaid::DEFAULT_SHOW_SOURCE,
              pan_zoom: Exporters::Mermaid::DEFAULT_PAN_ZOOM,
              mathjax: Exporters::Mermaid::DEFAULT_MATHJAX,
              mathjax_cdn: Exporters::Mermaid::DEFAULT_MATHJAX_CDN,
              inline_mathjax: false, self_contained: false, nonce: nil, csp: false,
              mermaid_sha256: nil, mathjax_sha256: nil,
              notes: Exporters::Mermaid::DEFAULT_NOTES,
              class_defs: Exporters::Mermaid::DEFAULT_CLASS_DEFS)
    Exporters::Mermaid.new(self, direction: direction, notes: notes, class_defs: class_defs).export_html(
      theme: theme,
      cdn: cdn,
      inline_mermaid: inline_mermaid,
      offline: offline,
      title: title,
      lang: lang,
      show_source: show_source,
      pan_zoom: pan_zoom,
      mathjax: mathjax,
      mathjax_cdn: mathjax_cdn,
      inline_mathjax: inline_mathjax,
      self_contained: self_contained,
      nonce: nonce,
      csp: csp,
      mermaid_sha256: mermaid_sha256,
      mathjax_sha256: mathjax_sha256
    )
  end

  def save_html(filename, direction: Exporters::Mermaid::DEFAULT_DIRECTION, theme: Exporters::Mermaid::DEFAULT_THEME,
                cdn: Exporters::Mermaid::DEFAULT_CDN, inline_mermaid: false, offline: false, title: nil,
                lang: Exporters::Mermaid::DEFAULT_LANG, show_source: Exporters::Mermaid::DEFAULT_SHOW_SOURCE,
                pan_zoom: Exporters::Mermaid::DEFAULT_PAN_ZOOM,
                mathjax: Exporters::Mermaid::DEFAULT_MATHJAX,
                mathjax_cdn: Exporters::Mermaid::DEFAULT_MATHJAX_CDN,
                inline_mathjax: false, self_contained: false, nonce: nil, csp: false,
                mermaid_sha256: nil, mathjax_sha256: nil,
                notes: Exporters::Mermaid::DEFAULT_NOTES,
                class_defs: Exporters::Mermaid::DEFAULT_CLASS_DEFS)
    AtomicFile.write(
      filename,
      to_html(
        direction: direction,
        theme: theme,
        cdn: cdn,
        inline_mermaid: inline_mermaid,
        offline: offline,
        title: title,
        lang: lang,
        show_source: show_source,
        pan_zoom: pan_zoom,
        mathjax: mathjax,
        mathjax_cdn: mathjax_cdn,
        inline_mathjax: inline_mathjax,
        self_contained: self_contained,
        nonce: nonce,
        csp: csp,
        mermaid_sha256: mermaid_sha256,
        mathjax_sha256: mathjax_sha256,
        notes: notes,
        class_defs: class_defs
      )
    )
  end

  def to_dot(direction: Exporters::Dot::DEFAULT_DIRECTION, theme: nil,
             rank_constraints: Exporters::Dot::DEFAULT_RANK_CONSTRAINTS)
    Exporters::Dot.new(self, direction: direction, theme: theme, rank_constraints: rank_constraints).export
  end

  def save_dot(filename, direction: Exporters::Dot::DEFAULT_DIRECTION, theme: nil,
               rank_constraints: Exporters::Dot::DEFAULT_RANK_CONSTRAINTS)
    AtomicFile.write(filename, to_dot(direction: direction, theme: theme, rank_constraints: rank_constraints))
  end

  def to_plantuml(direction: Exporters::Plantuml::DEFAULT_DIRECTION, theme: nil,
                  notes: Exporters::Plantuml::DEFAULT_NOTES)
    Exporters::Plantuml.new(self, direction: direction, theme: theme, notes: notes).export
  end

  def save_plantuml(filename, direction: Exporters::Plantuml::DEFAULT_DIRECTION, theme: nil,
                    notes: Exporters::Plantuml::DEFAULT_NOTES)
    AtomicFile.write(filename, to_plantuml(direction: direction, theme: theme, notes: notes))
  end

  private :layout_linear_positions,
          :layout_circle_positions,
          :layout_grid_positions,
          :layout_layered_positions,
          :layout_layered_groups,
          :layout_force_positions,
          :layout_graphviz_positions,
          :ordered_state_names,
          :crossing_reduced_layer_groups,
          :order_layer_by_neighbor_barycenter,
          :layer_neighbor_positions,
          :weak_components,
          :layered_distances,
          :graphviz_layout_state_ids,
          :graphviz_layout_dot,
          :graphviz_command_args,
          :graphviz_rankdir,
          :parse_graphviz_plain_positions,
          :normalize_graphviz_positions

  private

  def validate_finite_number!(value, name, positive: false, nonnegative: false)
    finite = value.is_a?(Numeric) && value.real? && value.to_f.finite?
    valid_range = if positive
                    finite && value.positive?
                  elsif nonnegative
                    finite && value >= 0
                  else
                    finite
                  end
    return value if valid_range

    qualifier = positive ? 'positive ' : (nonnegative ? 'non-negative ' : '')
    raise ArgumentError, "#{name} must be a #{qualifier}finite number"
  end

  def resolve_layout(layout)
    resolved = layout.to_sym
    return resolved if LAYOUT_OPTIONS.include?(resolved)

    raise ArgumentError, "Unknown SVG layout: #{layout.inspect}. Available layouts: #{LAYOUT_OPTIONS.join(', ')}"
  end

  def resolve_direction(direction)
    resolved = direction.to_sym
    return resolved if DIRECTION_OPTIONS.include?(resolved)

    raise ArgumentError, "Unknown direction: #{direction.inspect}. Available directions: #{DIRECTION_OPTIONS.join(', ')}"
  end

  def resolve_fit(fit)
    resolved = fit.to_sym
    return resolved if FIT_OPTIONS.include?(resolved)

    raise ArgumentError, "Unknown fit: #{fit.inspect}. Available values: #{FIT_OPTIONS.join(', ')}"
  end

  def resolve_state_kind(kind)
    return nil if kind.nil?

    resolved = kind.to_sym
    return resolved if STATE_KIND_OPTIONS.include?(resolved)

    raise ArgumentError, "Unknown state kind: #{kind.inspect}. Available values: #{STATE_KIND_OPTIONS.join(', ')}"
  end

  def resolve_initial_position(initial_position)
    resolved = initial_position.to_sym
    return resolved if INITIAL_POSITION_OPTIONS.include?(resolved)

    raise ArgumentError, "Unknown initial_position: #{initial_position.inspect}. Available values: #{INITIAL_POSITION_OPTIONS.join(', ')}"
  end

  def resolve_final_position(final_position)
    resolved = final_position.to_sym
    return resolved if FINAL_POSITION_OPTIONS.include?(resolved)

    raise ArgumentError, "Unknown final_position: #{final_position.inspect}. Available values: #{FINAL_POSITION_OPTIONS.join(', ')}"
  end

  def resolve_format(format)
    self.class::EXPORTERS.resolve(format)
  end

  def normalize_transition_label(label, epsilon_label: DEFAULT_EPSILON_LABEL, sort_labels: false)
    if label.is_a?(Array)
      labels = label.map { |item| normalize_single_transition_label(item, epsilon_label: epsilon_label) }.uniq
      labels = labels.sort_by(&:to_s) if sort_labels
      return Label.symbols(*labels.map(&:to_s))
    end

    normalize_single_transition_label(label, epsilon_label: epsilon_label)
  end

  def normalize_single_transition_label(label, epsilon_label: DEFAULT_EPSILON_LABEL)
    return label if label.is_a?(Label)
    return Label.epsilon(epsilon_label) if label == :epsilon

    label
  end

  def deep_copy(value, copies = {})
    case value
    when Hash
      return copies[value.object_id] if copies.key?(value.object_id)

      copy = {}
      copies[value.object_id] = copy
      value.each { |key, item| copy[deep_copy(key, copies)] = deep_copy(item, copies) }
      copy
    when Array
      return copies[value.object_id] if copies.key?(value.object_id)

      copy = []
      copies[value.object_id] = copy
      value.each { |item| copy << deep_copy(item, copies) }
      copy
    when String
      value.dup
    else
      value
    end
  end

  def immutable_copy(value)
    copy = deep_copy(value)
    deep_freeze(copy)
  end

  def immutable_snapshot(value)
    immutable_copy(value)
  end

  def deep_freeze(value)
    stack = [value]
    visited = {}
    until stack.empty?
      current = stack.pop
      next unless current.is_a?(Hash) || current.is_a?(Array) || current.is_a?(String)
      next if visited[current.object_id]

      visited[current.object_id] = true
      if current.is_a?(Hash)
        current.each { |key, item| stack << key << item }
      elsif current.is_a?(Array)
        current.each { |item| stack << item }
      end
      current.freeze
    end
    value.freeze
  end

  def reference_diagnostics
    diagnostics = []
    if @initial_state && !@states.key?(@initial_state)
      diagnostics << diagnostic(
        'undefined-initial-state',
        :error,
        ['initial'],
        "Initial state #{@initial_state.inspect} is not defined"
      )
    end
    @final_states.each_with_index do |state, index|
      next if @states.key?(state)

      diagnostics << diagnostic(
        'undefined-final-state',
        :error,
        ['final', index],
        "Final state #{state.inspect} is not defined"
      )
    end
    @transitions.each_with_index do |transition, index|
      unless @states.key?(transition.from)
        diagnostics << diagnostic(
          'undefined-transition-source',
          :error,
          ['transitions', index, 'from'],
          "Transition #{index} source #{transition.from.inspect} is not defined"
        )
      end
      next if @states.key?(transition.to)

      diagnostics << diagnostic(
        'undefined-transition-target',
        :error,
        ['transitions', index, 'to'],
        "Transition #{index} target #{transition.to.inspect} is not defined"
      )
    end
    hierarchy_validation_errors.each do |message|
      diagnostics << diagnostic('invalid-state-hierarchy', :error, ['states'], message)
    end
    diagnostics
  end

  def fsm_semantic_diagnostics
    diagnostics = []
    if @initial_state.nil?
      diagnostics << diagnostic(
        'missing-initial-state',
        :warning,
        ['initial'],
        'Automaton has no initial state',
        'Set an initial state before using reachability analysis.'
      )
    end
    if @final_states.empty?
      diagnostics << diagnostic(
        'missing-final-state',
        :warning,
        ['final'],
        'Automaton has no final states',
        'dead_states is empty when no accepting states are defined.'
      )
    end
    diagnostics
  end

  def dfa_diagnostics
    ensure_analysis_index!
    diagnostics = []
    @states.each_key do |from|
      by_symbol = Hash.new { |hash, key| hash[key] = [] }
      @outgoing_by_state[from].each do |transition|
        if transition.label.is_a?(Label) && transition.label.kind == :epsilon
          diagnostics << diagnostic(
            'epsilon-transition-in-dfa',
            :error,
            ['transitions', transition.id],
            "State #{from.inspect} has an epsilon transition"
          )
        end
        transition_label_symbols(transition.label).each { |symbol| by_symbol[symbol] << transition }
      end
      by_symbol.each do |symbol, transitions|
        next unless transitions.map(&:to).uniq.size > 1

        diagnostics << diagnostic(
          'nondeterministic-transition',
          :error,
          ['states', from],
          "State #{from.inspect} has multiple targets for label #{symbol.inspect}"
        )
      end
    end
    diagnostics.uniq(&:message)
  end

  def transition_label_symbols(label)
    return label.value if label.is_a?(Label) && label.kind == :symbols

    [label.to_s]
  end

  def diagnostic(code, severity, path, message, hint = nil)
    Diagnostic.new(code: code, severity: severity, path: path.freeze, message: message, hint: hint)
  end

  def ensure_analysis_index!
    return if @analysis_index_revision == @revision

    @outgoing_by_state = @states.each_key.to_h { |state| [state, []] }
    @incoming_by_state = @states.each_key.to_h { |state| [state, []] }
    @undirected_neighbors = @states.each_key.to_h { |state| [state, []] }
    @transitions_by_directed_pair = Hash.new { |hash, key| hash[key] = [] }
    @transitions_by_undirected_pair = Hash.new { |hash, key| hash[key] = [] }
    @transitions.each do |transition|
      @transitions_by_directed_pair[[transition.from, transition.to]] << transition
      @transitions_by_undirected_pair[Set[transition.from, transition.to].freeze] << transition
      next unless @states.key?(transition.from) && @states.key?(transition.to)

      @outgoing_by_state[transition.from] << transition
      @incoming_by_state[transition.to] << transition
      @undirected_neighbors[transition.from] << transition.to unless @undirected_neighbors[transition.from].include?(transition.to)
      @undirected_neighbors[transition.to] << transition.from unless @undirected_neighbors[transition.to].include?(transition.from)
    end
    @analysis_index_revision = @revision
  end

  def transition_index(identifier)
    transition_id = identifier.is_a?(Transition) ? identifier.id : identifier
    index = @transitions.index { |transition| transition.id == transition_id }
    return index if index

    raise ArgumentError, "Transition is not defined: #{identifier.inspect}"
  end

  def graph_changed!
    @revision += 1
    @analysis_index_revision = nil
    @state_positions = {}
    @layout_cache.clear
    self
  end

  def hierarchy_validation_errors
    errors = []
    parents = {}

    @states.each do |name, state|
      metadata = state[:metadata]
      next unless metadata.is_a?(Hash)

      parent = metadata[:parent] || metadata['parent']
      group = metadata[:group] || metadata['group'] || metadata[:cluster] || metadata['cluster']
      errors << "State #{name.inspect} cannot define both parent and group" if parent && group
      next unless parent

      unless @states.key?(parent)
        errors << "State #{name.inspect} parent #{parent.inspect} is not defined"
        next
      end
      parents[name] = parent
    end

    reported = {}
    parents.each_key do |start|
      path = []
      indexes = {}
      current = start
      while parents.key?(current)
        if indexes.key?(current)
          cycle = path[indexes[current]..] + [current]
          key = cycle[0...-1].to_h { |state| [state, true] }
          unless key.keys.any? { |state| reported[state] }
            errors << "State hierarchy contains a cycle: #{cycle.map(&:inspect).join(' -> ')}"
            key.each_key { |state| reported[state] = true }
          end
          break
        end

        indexes[current] = path.length
        path << current
        current = parents[current]
      end
    end

    errors
  end

  def fit_positions(positions, width, height, state_radius, padding, fit)
    return positions if positions.empty?

    margin = [padding.to_f, state_radius.to_f].max
    target_width = width.to_f - (2 * margin)
    target_height = height.to_f - (2 * margin)
    center_x = width.to_f / 2.0
    center_y = height.to_f / 2.0

    if target_width <= 0 || target_height <= 0
      return positions.transform_values { { x: center_x, y: center_y } }
    end

    x_values = positions.values.map { |position| position[:x].to_f }
    y_values = positions.values.map { |position| position[:y].to_f }
    min_x, max_x = x_values.minmax
    min_y, max_y = y_values.minmax
    span_x = max_x - min_x
    span_y = max_y - min_y

    if span_x.zero? && span_y.zero?
      return positions.transform_values { { x: center_x, y: center_y } }
    end

    scale_x = span_x.zero? ? nil : target_width / span_x
    scale_y = span_y.zero? ? nil : target_height / span_y
    return cover_positions(positions, min_x, min_y, span_x, span_y, margin, center_x, center_y, scale_x, scale_y) if fit == :cover

    scale = [scale_x || Float::INFINITY, scale_y || Float::INFINITY].min
    scaled_width = span_x * scale
    scaled_height = span_y * scale
    offset_x = margin + ((target_width - scaled_width) / 2.0)
    offset_y = margin + ((target_height - scaled_height) / 2.0)

    positions.transform_values do |position|
      {
        x: span_x.zero? ? center_x : offset_x + ((position[:x].to_f - min_x) * scale),
        y: span_y.zero? ? center_y : offset_y + ((position[:y].to_f - min_y) * scale)
      }
    end
  end

  def cover_positions(positions, min_x, min_y, span_x, span_y, margin, center_x, center_y, scale_x, scale_y)
    positions.transform_values do |position|
      {
        x: span_x.zero? ? center_x : margin + ((position[:x].to_f - min_x) * scale_x),
        y: span_y.zero? ? center_y : margin + ((position[:y].to_f - min_y) * scale_y)
      }
    end
  end

  def arrange_auto_states(auto_states, initial_position:, final_position:)
    ordered = auto_states.uniq

    if initial_position == :start && @initial_state && ordered.include?(@initial_state)
      ordered.delete(@initial_state)
      ordered.unshift(@initial_state)
    end

    return ordered unless final_position == :end

    non_final_states = ordered.reject { |name| @final_states.include?(name) }
    final_states = ordered.select { |name| @final_states.include?(name) }
    non_final_states + final_states
  end

  def avoid_fixed_position_collisions(auto_positions, fixed_positions, width, height, state_radius, padding, spacing, direction)
    return auto_positions if fixed_positions.empty? || auto_positions.empty?

    minimum_distance = [spacing.to_f, state_radius.to_f * 2.5].max
    occupied = fixed_positions.values.map(&:dup)
    auto_positions.each_with_object({}) do |(name, position), adjusted|
      candidate = position.dup
      if position_collides?(candidate, occupied, minimum_distance)
        offsets = collision_avoidance_offsets(occupied.size + auto_positions.size + 1, minimum_distance, direction)
        candidates = offsets.map { |offset_x, offset_y| { x: position[:x] + offset_x, y: position[:y] + offset_y } }
        candidate = candidates.find do |item|
          position_inside_canvas?(item, width, height, state_radius, padding) &&
            !position_collides?(item, occupied, minimum_distance)
        end
        candidate ||= candidates.find { |item| !position_collides?(item, occupied, minimum_distance) }
        candidate ||= position
      end

      adjusted[name] = candidate
      occupied << candidate
    end
  end

  def collision_avoidance_offsets(rings, spacing, direction)
    (1..rings).flat_map do |ring|
      distance = spacing * ring
      if %i[lr rl].include?(direction)
        [[0, -distance], [0, distance], [-distance, 0], [distance, 0],
         [-distance, -distance], [distance, -distance], [-distance, distance], [distance, distance]]
      else
        [[-distance, 0], [distance, 0], [0, -distance], [0, distance],
         [-distance, -distance], [-distance, distance], [distance, -distance], [distance, distance]]
      end
    end
  end

  def position_collides?(position, occupied, minimum_distance)
    occupied.any? do |other|
      Math.hypot(position[:x] - other[:x], position[:y] - other[:y]) < minimum_distance
    end
  end

  def position_inside_canvas?(position, width, height, state_radius, padding)
    margin = [state_radius.to_f, padding.to_f].max
    position[:x] >= margin && position[:x] <= width.to_f - margin &&
      position[:y] >= margin && position[:y] <= height.to_f - margin
  end

  def manual_position?(state)
    @manual_states[state]
  end

  def layout_linear_position(index, _count, width, height, margin, horizontal_step, vertical_step, direction)
    case direction
    when :lr
      x = margin + (index * horizontal_step)
      y = height / 2.0
    when :rl
      x = width - margin - (index * horizontal_step)
      y = height / 2.0
    when :tb
      x = width / 2.0
      y = margin + (index * vertical_step)
    when :bt
      x = width / 2.0
      y = height - margin - (index * vertical_step)
    end

    { x: x, y: y }
  end
end
