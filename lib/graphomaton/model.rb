# frozen_string_literal: true

require 'set'

class Graphomaton
  module ModelValue
    def self.copy(value, copies = {})
      case value
      when Hash
        return copies[value.object_id] if copies.key?(value.object_id)

        duplicate = {}
        copies[value.object_id] = duplicate
        value.each { |key, item| duplicate[copy(key, copies)] = copy(item, copies) }
        duplicate.freeze
      when Array
        return copies[value.object_id] if copies.key?(value.object_id)

        duplicate = []
        copies[value.object_id] = duplicate
        value.each { |item| duplicate << copy(item, copies) }
        duplicate.freeze
      when Set
        return copies[value.object_id] if copies.key?(value.object_id)

        duplicate = Set.new
        copies[value.object_id] = duplicate
        value.each { |item| duplicate << copy(item, copies) }
        duplicate.freeze
      when String
        value.dup.freeze
      else
        value
      end
    end
  end
  private_constant :ModelValue

  Label = Data.define(:kind, :value) do
    KINDS = %i[text symbols epsilon uml alternatives].freeze

    def initialize(kind:, value: nil)
      resolved_kind = kind.to_sym
      raise ArgumentError, "Unknown label kind: #{kind.inspect}" unless KINDS.include?(resolved_kind)

      normalized_value = case resolved_kind
                         when :text
                           value.to_s
                         when :symbols
                           symbols = Array(value).map(&:to_s)
                           raise ArgumentError, 'Symbol label requires at least one symbol' if symbols.empty?

                           symbols
                         when :epsilon
                           value.nil? ? Graphomaton::DEFAULT_EPSILON_LABEL : value.to_s
                         when :uml
                           raise ArgumentError, 'UML label value must be a Hash' unless value.is_a?(Hash)

                           uml_value = {
                             event: value.key?(:event) ? value[:event] : value['event'],
                             guard: value.key?(:guard) ? value[:guard] : value['guard'],
                             action: value.key?(:action) ? value[:action] : value['action']
                           }.compact
                           raise ArgumentError, 'UML label requires an event' unless uml_value.key?(:event)

                           uml_value
                         when :alternatives
                           alternatives = Array(value)
                           raise ArgumentError, 'Alternative label requires at least one label' if alternatives.empty?

                           alternatives
                         end
      super(kind: resolved_kind, value: ModelValue.copy(normalized_value))
    end

    def self.text(value)
      new(kind: :text, value: value)
    end

    def self.symbols(*values)
      new(kind: :symbols, value: values.flatten)
    end

    def self.epsilon(display = Graphomaton::DEFAULT_EPSILON_LABEL)
      new(kind: :epsilon, value: display)
    end

    def self.uml(event:, guard: nil, action: nil)
      new(kind: :uml, value: { event: event, guard: guard, action: action }.compact)
    end

    def self.alternatives(*values)
      new(kind: :alternatives, value: values.flatten)
    end

    def to_s
      case kind
      when :symbols
        value.join(', ')
      when :epsilon
        value
      when :uml
        event = value.fetch(:event).to_s
        guard = value[:guard] ? " [#{value[:guard]}]" : ''
        action = value[:action] ? " / #{value[:action]}" : ''
        "#{event}#{guard}#{action}"
      when :alternatives
        value.join(', ')
      else
        value.to_s
      end
    end

    def to_h
      serialized = kind == :alternatives ? value.map { |label| label.is_a?(Label) ? label.to_h : label } : value
      { type: kind, value: serialized }.compact
    end
  end

  State = Data.define(:id, :x, :y, :label, :style, :metadata, :shape, :kind) do
    MISSING = Object.new.freeze

    def initialize(id:, x:, y:, label:, style:, metadata:, shape:, kind:)
      super(
        id: ModelValue.copy(id),
        x: x,
        y: y,
        label: ModelValue.copy(label),
        style: ModelValue.copy(style),
        metadata: ModelValue.copy(metadata),
        shape: ModelValue.copy(shape),
        kind: kind.nil? ? nil : kind.to_sym
      )
    end

    def [](key)
      return id if key == :name || key == :id

      public_send(key)
    rescue NoMethodError
      nil
    end

    def fetch(key, default = MISSING)
      value = self[key]
      return value unless value.nil?
      return default unless default.equal?(MISSING)

      raise KeyError, "key not found: #{key.inspect}"
    end

    def to_h
      output = { name: id, x: x, y: y }
      output[:label] = label unless label.nil?
      output[:style] = style unless style.nil?
      output[:metadata] = metadata unless metadata.nil?
      output[:shape] = shape unless shape.nil?
      output[:kind] = kind unless kind.nil?
      output
    end
  end

  Transition = Data.define(:id, :from, :to, :label, :style, :metadata, :line_style) do
    def initialize(id:, from:, to:, label:, style:, metadata:, line_style:)
      super(
        id: id,
        from: ModelValue.copy(from),
        to: ModelValue.copy(to),
        label: ModelValue.copy(label),
        style: ModelValue.copy(style),
        metadata: ModelValue.copy(metadata),
        line_style: ModelValue.copy(line_style)
      )
    end

    def [](key)
      public_send(key)
    rescue NoMethodError
      nil
    end

    def to_h
      output = { from: from, to: to, label: label.is_a?(Label) ? label.to_s : label }
      output[:style] = style unless style.nil?
      output[:metadata] = metadata unless metadata.nil?
      output[:line_style] = line_style unless line_style.nil?
      output
    end
  end

  Diagnostic = Data.define(:code, :severity, :path, :message, :hint) do
    def initialize(code:, severity:, path:, message:, hint: nil)
      super(
        code: ModelValue.copy(code.to_s),
        severity: severity.to_sym,
        path: ModelValue.copy(Array(path)),
        message: ModelValue.copy(message.to_s),
        hint: hint.nil? ? nil : ModelValue.copy(hint.to_s)
      )
    end

    def to_h
      { code: code, severity: severity, path: path, message: message, hint: hint }.compact
    end
  end


  RenderOptions = Data.define(:format, :width, :height, :options) do
    def initialize(format: :svg, width: 800, height: 600, options: {})
      super(format: format.to_sym, width: width, height: height, options: ModelValue.copy(options))
    end
  end

  SvgOptions = Data.define(:width, :height, :options) do
    def initialize(width: 800, height: 600, **options)
      super(width: width, height: height, options: ModelValue.copy(options))
    end
  end

  RenderResult = Data.define(:output, :diagnostics, :bounds, :layout) do
    def initialize(output:, diagnostics:, bounds:, layout:)
      super(
        output: ModelValue.copy(output),
        diagnostics: ModelValue.copy(Array(diagnostics)),
        bounds: ModelValue.copy(bounds),
        layout: ModelValue.copy(layout)
      )
    end
  end
end
