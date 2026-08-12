# frozen_string_literal: true

require 'open3'

require_relative 'svg'

class Graphomaton
  module Exporters
    class Webp
      include Graphomaton::ExporterIntrospection
      class ConversionError < Graphomaton::ConversionError; end

      DEFAULT_CONVERTER = :auto
      DEFAULT_TIMEOUT = ProcessRunner::DEFAULT_TIMEOUT
      DEFAULT_MAX_OUTPUT_BYTES = ProcessRunner::DEFAULT_MAX_STDOUT_BYTES
      PNG_SIGNATURE = "\x89PNG\r\n\x1A\n".b.freeze

      CONVERTER_COMMANDS = {
        rsvg_magick: [
          ['rsvg-convert', '--format', 'png', '-'],
          ['magick', 'png:-', 'webp:-']
        ],
        magick: ['magick', 'svg:-', 'webp:-'],
        convert: ['convert', 'svg:-', 'webp:-']
      }.freeze
      CONVERTER_OPTIONS = ([:auto] + CONVERTER_COMMANDS.keys).freeze

      def self.available?(converter: DEFAULT_CONVERTER)
        !available_command(converter: converter).nil?
      end

      def self.available_command(converter: DEFAULT_CONVERTER)
        resolved_converter = resolve_converter(converter)
        if resolved_converter != :auto
          command = CONVERTER_COMMANDS[resolved_converter]
          return command if command_available?(command)
        end
        return nil if resolved_converter != :auto

        CONVERTER_COMMANDS.values.find { |command| command_available?(command) }
      end

      def initialize(automaton)
        @automaton = automaton
      end

      def export(width = 800, height = 600, theme: Svg::DEFAULT_THEME, converter: DEFAULT_CONVERTER,
                 timeout: DEFAULT_TIMEOUT, max_output_bytes: DEFAULT_MAX_OUTPUT_BYTES, **svg_options)
        command = available_command(converter: converter)
        raise ConversionError, missing_converter_message(converter) unless command

        svg = Svg.new(@automaton).export(width, height, theme: theme, **svg_options)
        webp, error, status = run_conversion(
          command,
          svg,
          timeout: timeout,
          max_output_bytes: max_output_bytes
        )
        webp = webp.b

        return webp if status.success? && webp?(webp)
        raise ConversionError, invalid_webp_message(command, error) if status.success?

        raise ConversionError, failed_conversion_message(command, error)
      rescue ProcessRunner::Error => e
        raise ConversionError, failed_conversion_message(command, e.message)
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

      def self.command_available?(command)
        stages = command.first.is_a?(Array) ? command : [command]
        stages.all? { |stage| executable?(stage.first) }
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

      def run_conversion(command, svg, timeout:, max_output_bytes:)
        unless command.first.is_a?(Array)
          return ProcessRunner.capture3(
            *command,
            stdin_data: svg,
            binmode: true,
            timeout: timeout,
            max_stdout_bytes: max_output_bytes
          )
        end

        raster_command, webp_command = command
        png, raster_error, raster_status = ProcessRunner.capture3(
          *raster_command,
          stdin_data: svg,
          binmode: true,
          timeout: timeout,
          max_stdout_bytes: max_output_bytes
        )
        unless raster_status.success? && png.b.start_with?(PNG_SIGNATURE)
          detail = raster_error.to_s.strip
          detail = 'converter did not produce PNG data' if detail.empty?
          raise ConversionError, "Failed to rasterize SVG using #{raster_command.first}: #{detail}"
        end

        ProcessRunner.capture3(
          *webp_command,
          stdin_data: png,
          binmode: true,
          timeout: timeout,
          max_stdout_bytes: max_output_bytes
        )
      end

      def missing_converter_message(converter)
        resolved_converter = self.class.resolve_converter(converter)
        required = if resolved_converter == :auto
                     'magick or convert (optionally with rsvg-convert)'
                   else
                     CONVERTER_COMMANDS[resolved_converter].first
                   end

        "WebP export requires #{required} to be installed. #{install_hint}"
      end

      def install_hint
        'Install hints: macOS: brew install imagemagick librsvg; Debian/Ubuntu: apt install imagemagick librsvg2-bin; Windows: install ImageMagick.'
      end

      def failed_conversion_message(command, error)
        detail = error.to_s.strip
        detail = 'unknown error' if detail.empty?

        "Failed to convert SVG to WebP using #{converter_name(command)}: #{detail}"
      end

      def invalid_webp_message(command, error)
        detail = error.to_s.strip
        return "Failed to convert SVG to WebP using #{converter_name(command)}: converter did not produce WebP data" if detail.empty?

        "Failed to convert SVG to WebP using #{converter_name(command)}: converter did not produce WebP data (#{detail})"
      end

      def converter_name(command)
        return command.first unless command.first.is_a?(Array)

        command.map(&:first).join(' + ')
      end
    end
  end
end
