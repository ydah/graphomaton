# frozen_string_literal: true

require 'open3'

require_relative 'svg'

class Graphomaton
  module Exporters
    class Webp
      class ConversionError < StandardError; end

      DEFAULT_CONVERTER = :auto

      CONVERTER_COMMANDS = {
        magick: ['magick', 'svg:-', 'webp:-'],
        convert: ['convert', 'svg:-', 'webp:-']
      }.freeze
      CONVERTER_OPTIONS = ([:auto] + CONVERTER_COMMANDS.keys).freeze

      def self.available?(converter: DEFAULT_CONVERTER)
        !available_command(converter: converter).nil?
      end

      def self.available_command(converter: DEFAULT_CONVERTER)
        resolved_converter = resolve_converter(converter)
        return CONVERTER_COMMANDS[resolved_converter] if resolved_converter != :auto && executable?(CONVERTER_COMMANDS[resolved_converter].first)
        return nil if resolved_converter != :auto

        CONVERTER_COMMANDS.values.find { |command| executable?(command.first) }
      end

      def initialize(automaton)
        @automaton = automaton
      end

      def export(width = 800, height = 600, theme: Svg::DEFAULT_THEME, converter: DEFAULT_CONVERTER, **svg_options)
        command = available_command(converter: converter)
        raise ConversionError, missing_converter_message(converter) unless command

        svg = Svg.new(@automaton).export(width, height, theme: theme, **svg_options)
        webp, error, status = Open3.capture3(*command, stdin_data: svg, binmode: true)
        webp = webp.b

        return webp if status.success? && webp?(webp)
        raise ConversionError, invalid_webp_message(command, error) if status.success?

        raise ConversionError, failed_conversion_message(command, error)
      end

      private

      def available_command(converter: DEFAULT_CONVERTER)
        self.class.available_command(converter: converter)
      end

      def self.executable?(command)
        paths.any? do |path|
          executable_path = File.join(path, command)
          File.file?(executable_path) && File.executable?(executable_path)
        end
      end

      def self.resolve_converter(converter)
        resolved = converter.to_sym
        return resolved if CONVERTER_OPTIONS.include?(resolved)

        raise ArgumentError, "Unknown WebP converter: #{converter.inspect}. Available converters: #{CONVERTER_OPTIONS.join(', ')}"
      end

      def self.paths
        ENV.fetch('PATH', '').split(File::PATH_SEPARATOR)
      end

      def webp?(data)
        data.start_with?('RIFF') && data.byteslice(8, 4) == 'WEBP'
      end

      def missing_converter_message(converter)
        resolved_converter = self.class.resolve_converter(converter)
        required = if resolved_converter == :auto
                     'magick or convert'
                   else
                     CONVERTER_COMMANDS[resolved_converter].first
                   end

        "WebP export requires #{required} to be installed. #{install_hint}"
      end

      def install_hint
        'Install hints: macOS: brew install imagemagick; Debian/Ubuntu: apt install imagemagick; Windows: install ImageMagick.'
      end

      def failed_conversion_message(command, error)
        detail = error.to_s.strip
        detail = 'unknown error' if detail.empty?

        "Failed to convert SVG to WebP using #{command.first}: #{detail}"
      end

      def invalid_webp_message(command, error)
        detail = error.to_s.strip
        return "Failed to convert SVG to WebP using #{command.first}: converter did not produce WebP data" if detail.empty?

        "Failed to convert SVG to WebP using #{command.first}: converter did not produce WebP data (#{detail})"
      end
    end
  end
end
