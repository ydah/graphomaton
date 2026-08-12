# frozen_string_literal: true

class Graphomaton
  # Assigns deterministic, collision-free identifiers within one export.
  class IdentifierAllocator
    def initialize(reserved: [])
      @identifiers = {}
      @used = reserved.to_h { |identifier| [identifier.to_s, true] }
      @counters = Hash.new(0)
    end

    def allocate(key, preferred: nil, prefix: 'id')
      return @identifiers[key] if @identifiers.key?(key)

      candidate = preferred.to_s unless preferred.nil?
      candidate = nil if candidate&.empty? || @used.key?(candidate)
      candidate ||= next_identifier(prefix)

      @used[candidate] = true
      @identifiers[key] = candidate
    end

    private

    def next_identifier(prefix)
      loop do
        @counters[prefix] += 1
        candidate = "#{prefix}_#{@counters[prefix]}"
        return candidate unless @used.key?(candidate)
      end
    end
  end
end
