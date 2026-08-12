# frozen_string_literal: true

class Graphomaton
  class ExporterRegistry
    Entry = Data.define(:name, :aliases, :extensions, :binary, :capabilities, :loader)

    def initialize
      @entries = {}
      @aliases = {}
    end

    def register(name, aliases: [], extensions: [], binary: false, capabilities: [], &loader)
      canonical = name.to_sym
      entry = Entry.new(
        name: canonical,
        aliases: aliases.map(&:to_sym).freeze,
        extensions: extensions.map { |extension| extension.to_s.delete_prefix('.').downcase }.freeze,
        binary: binary,
        capabilities: capabilities.map(&:to_sym).freeze,
        loader: loader
      )
      @entries[canonical] = entry
      ([canonical] + entry.aliases + entry.extensions.map(&:to_sym)).each { |key| @aliases[key] = canonical }
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
      pseudostate: ->(graph) { graph.state_records.any? { |_, state| metadata_value(state.metadata, :kind, :type) } },
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
