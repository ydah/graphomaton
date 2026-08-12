# frozen_string_literal: true

class Graphomaton
  class ExporterRegistry
    Entry = Data.define(:name, :aliases, :extensions, :binary, :capabilities, :loader) do
      def exporter
        resolved = loader.call
        return resolved if resolved.respond_to?(:new)

        raise ArgumentError, "Exporter #{name.inspect} loader must return a class"
      end
    end

    def initialize
      @entries = {}
      @aliases = {}
    end

    def register(name, aliases: [], extensions: [], binary: false, capabilities: [], exporter: nil, &loader)
      canonical = name.to_sym
      resolved_loader = loader || (-> { exporter })
      raise ArgumentError, "Exporter #{canonical.inspect} requires an exporter class or loader block" unless exporter || loader

      keys = [canonical] + aliases.map(&:to_sym) + extensions.map { |extension| extension.to_s.delete_prefix('.').downcase.to_sym }
      collisions = keys.select { |key| @aliases.key?(key) }.uniq
      unless collisions.empty?
        raise ArgumentError, "Exporter identifiers are already registered: #{collisions.join(', ')}"
      end

      entry = Entry.new(
        name: canonical,
        aliases: aliases.map(&:to_sym).freeze,
        extensions: extensions.map { |extension| extension.to_s.delete_prefix('.').downcase }.freeze,
        binary: binary,
        capabilities: capabilities.map(&:to_sym).freeze,
        loader: resolved_loader
      )
      @entries[canonical] = entry
      ([canonical] + entry.aliases + entry.extensions.map(&:to_sym)).each { |key| @aliases[key] = canonical }
      entry
    end

    def unregister(format)
      canonical = resolve(format)
      entry = @entries.delete(canonical)
      @aliases.delete_if { |_key, value| value == canonical }
      entry
    end

    def resolve(format)
      key = format.to_s.delete_prefix('.').downcase.to_sym
      canonical = @aliases[key]
      return canonical if canonical

      raise ArgumentError, "Unknown format: #{format.inspect}. Available formats: #{formats.join(', ')}"
    end

    def fetch(format)
      @entries.fetch(resolve(format))
    end

    def formats
      @entries.keys.freeze
    end

    def aliases
      @aliases.dup.freeze
    end
  end

  module ExporterCapabilities
    FEATURE_DETECTORS = {
      state_style: ->(graph) { graph.state_records.any? { |_, state| state.style } },
      transition_style: ->(graph) { graph.transition_records.any? { |transition| transition.style } },
      url: lambda { |graph|
        graph.state_records.any? { |_, state| metadata_value(state.metadata, :url, :href) } ||
          graph.transition_records.any? { |transition| metadata_value(transition.metadata, :url, :href) }
      },
      tooltip: lambda { |graph|
        graph.state_records.any? { |_, state| metadata_value(state.metadata, :tooltip, :description) } ||
          graph.transition_records.any? { |transition| metadata_value(transition.metadata, :tooltip, :description) }
      },
      group: ->(graph) { graph.state_records.any? { |_, state| metadata_value(state.metadata, :group, :cluster) } },
      parent: ->(graph) { graph.state_records.any? { |_, state| metadata_value(state.metadata, :parent) } },
      pseudostate: lambda { |graph|
        graph.state_records.any? do |_, state|
          (state.kind && state.kind != :normal) || metadata_value(state.metadata, :kind, :type)
        end
      },
      bundle: ->(graph) { graph.transition_records.any? { |transition| metadata_value(transition.metadata, :bundle) } },
      line_style: ->(graph) { graph.transition_records.any?(&:line_style) }
    }.freeze

    def self.losses_for(graph, capabilities)
      FEATURE_DETECTORS.filter_map do |feature, detector|
        feature if detector.call(graph) && !capabilities.include?(feature)
      end
    end

    def self.metadata_value(metadata, *keys)
      return nil unless metadata.is_a?(Hash)

      keys.each do |key|
        value = metadata[key] || metadata[key.to_s]
        return value if value
      end
      nil
    end
    private_class_method :metadata_value
  end

  module ExporterIntrospection
    def capabilities
      Graphomaton.exporter_capabilities(exporter_format)
    end

    def losses_for(graph = @automaton)
      Graphomaton::ExporterCapabilities.losses_for(graph, capabilities)
    end

    private

    def exporter_format
      self.class.name.split('::').last.downcase.to_sym
    end
  end
end
