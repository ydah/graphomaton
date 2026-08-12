# frozen_string_literal: true

class Graphomaton
  # Validates untrusted model input before it reaches exporters or graph analysis.
  class InputPolicy
    XML_INVALID_CHARACTERS = /[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F\uFFFE\uFFFF]/
    TOP_LEVEL_KEYS = %i[version states transitions initial initial_state final final_states].freeze
    STATE_KEYS = %i[id name x y label style metadata shape kind initial final accepting].freeze
    TRANSITION_KEYS = %i[from to label style metadata line_style].freeze

    def self.text!(value, context:, max_bytes: nil)
      return value unless value.is_a?(String)

      unless value.encoding == Encoding::UTF_8 ? value.valid_encoding? : value.dup.force_encoding(Encoding::UTF_8).valid_encoding?
        raise ArgumentError, "#{context} must be valid UTF-8"
      end
      utf8 = value.encoding == Encoding::UTF_8 ? value : value.encode(Encoding::UTF_8)
      raise ArgumentError, "#{context} contains characters that are invalid in XML" if utf8.match?(XML_INVALID_CHARACTERS)
      if max_bytes && utf8.bytesize > max_bytes
        raise ArgumentError, "#{context} exceeds max_label_length (#{max_bytes})"
      end

      value
    end

    def self.identifier!(value, context:)
      raise ArgumentError, "#{context} cannot be nil" if value.nil?

      text!(value, context: context)
      value
    end

    def self.label!(value, context:, max_bytes: nil)
      if value.is_a?(Hash) || value.is_a?(Array)
        raise ArgumentError, "#{context} must be scalar text or a Graphomaton::Label"
      end

      text!(value.to_s, context: context, max_bytes: max_bytes) unless value.nil?
      value
    end

    def self.mapping!(value, context:)
      return value if value.nil? || value.is_a?(Hash)

      raise ArgumentError, "#{context} must be a Hash"
    end

    def self.boolean!(value, context:)
      return value if value == true || value == false || value.nil?

      raise ArgumentError, "#{context} must be true or false"
    end

    def self.known_keys!(hash, allowed, context:, strict:)
      return unless strict

      unknown = hash.keys.reject { |key| allowed.include?(key.to_s.to_sym) }
      return if unknown.empty?

      raise ArgumentError, "Unknown #{context} keys: #{unknown.join(', ')}"
    end

    def self.nested_depth!(value, maximum:, context:, max_string_bytes: nil)
      raise ArgumentError, 'max_metadata_depth must be a positive Integer' unless maximum.is_a?(Integer) && maximum.positive?

      stack = [[value, 1]]
      visited = {}
      until stack.empty?
        current, depth = stack.pop
        text!(current, context: context, max_bytes: max_string_bytes) if current.is_a?(String)
        next unless current.is_a?(Hash) || current.is_a?(Array)
        next if visited[current.object_id]

        raise ArgumentError, "#{context} exceeds max_metadata_depth (#{maximum})" if depth > maximum

        visited[current.object_id] = true
        children = current.is_a?(Hash) ? current.flat_map { |key, item| [key, item] } : current
        children.each { |child| stack << [child, depth + 1] }
      end
    end
  end
end
