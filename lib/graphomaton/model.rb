# frozen_string_literal: true

class Graphomaton
  Label = Data.define(:kind, :value) do
    KINDS = %i[text symbols epsilon uml].freeze

    def initialize(kind:, value: nil)
      resolved_kind = kind.to_sym
      raise ArgumentError, "Unknown label kind: #{kind.inspect}" unless KINDS.include?(resolved_kind)

      super(kind: resolved_kind, value: value)
    end

    def self.text(value)
      new(kind: :text, value: value.to_s)
    end

    def self.symbols(*values)
      new(kind: :symbols, value: values.flatten.map(&:to_s).freeze)
    end

    def self.epsilon
      new(kind: :epsilon)
    end

    def self.uml(event:, guard: nil, action: nil)
      new(kind: :uml, value: { event: event, guard: guard, action: action }.compact.freeze)
    end

    def to_s
      case kind
      when :symbols
        value.join(', ')
      when :epsilon
        Graphomaton::DEFAULT_EPSILON_LABEL
      when :uml
        event = value.fetch(:event).to_s
        guard = value[:guard] ? " [#{value[:guard]}]" : ''
        action = value[:action] ? " / #{value[:action]}" : ''
        "#{event}#{guard}#{action}"
      else
        value.to_s
      end
    end

    def to_h
      { type: kind, value: value }.compact
    end
  end

  State = Data.define(:id, :x, :y, :label, :style, :metadata, :shape) do
    MISSING = Object.new.freeze

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
      output
    end
  end

  Transition = Data.define(:id, :from, :to, :label, :style, :metadata, :line_style) do
    def [](key)
      public_send(key)
    rescue NoMethodError
      nil
    end

    def to_h
      output = { from: from, to: to, label: label }
      output[:style] = style unless style.nil?
      output[:metadata] = metadata unless metadata.nil?
      output[:line_style] = line_style unless line_style.nil?
      output
    end
  end

  Diagnostic = Data.define(:code, :severity, :path, :message, :hint) do
    def to_h
      { code: code, severity: severity, path: path, message: message, hint: hint }.compact
    end
  end


  RenderOptions = Data.define(:format, :width, :height, :options) do
    def initialize(format: :svg, width: 800, height: 600, options: {})
      super(format: format.to_sym, width: width, height: height, options: options.dup.freeze)
    end
  end

  SvgOptions = Data.define(:width, :height, :options) do
    def initialize(width: 800, height: 600, **options)
      super(width: width, height: height, options: options.freeze)
    end
  end
end
