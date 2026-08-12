# frozen_string_literal: true

require 'open3'

require_relative 'svg'

class Graphomaton
  module Exporters
    class Png
      include Graphomaton::ExporterIntrospection
      class ConversionError < Graphomaton::ConversionError; end

      PNG_SIGNATURE = "\x89PNG\r\n\x1A\n".b.freeze
      DEFAULT_SCALE = 1.0
      DEFAULT_CONVERTER = :auto
      DEFAULT_TIMEOUT = ProcessRunner::DEFAULT_TIMEOUT
      DEFAULT_MAX_OUTPUT_BYTES = ProcessRunner::DEFAULT_MAX_STDOUT_BYTES

      CONVERTER_COMMANDS = {
        rsvg: ['rsvg-convert', '--format', 'png', '-'],
        magick: ['magick', 'svg:-', 'png:-'],
        convert: ['convert', 'svg:-', 'png:-']
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

      def export(width = 800, height = 600, theme: Svg::DEFAULT_THEME, scale: DEFAULT_SCALE, converter: DEFAULT_CONVERTER,
                 timeout: DEFAULT_TIMEOUT, max_output_bytes: DEFAULT_MAX_OUTPUT_BYTES, **svg_options)
        export_result(
          width,
          height,
          theme: theme,
          scale: scale,
          converter: converter,
          timeout: timeout,
          max_output_bytes: max_output_bytes,
          **svg_options
        ).output
      end

      def export_result(width = 800, height = 600, theme: Svg::DEFAULT_THEME, scale: DEFAULT_SCALE, converter: DEFAULT_CONVERTER,
                        timeout: DEFAULT_TIMEOUT, max_output_bytes: DEFAULT_MAX_OUTPUT_BYTES, **svg_options)
        command = available_command(converter: converter)
        raise ConversionError, missing_converter_message(converter) unless command

        resolved_scale = resolve_scale(scale)
        svg_result = Svg.new(@automaton).export_result(width, height, theme: theme, **svg_options)
        svg = scale_svg_dimensions(svg_result.output, resolved_scale)
        png, error, status = ProcessRunner.capture3(
          *command,
          stdin_data: svg,
          binmode: true,
          timeout: timeout,
          max_stdout_bytes: max_output_bytes
        )
        png = png.b

        if status.success? && png.start_with?(PNG_SIGNATURE)
          return RenderResult.new(
            output: png.freeze,
            diagnostics: svg_result.diagnostics,
            bounds: svg_result.bounds,
            layout: svg_result.layout
          )
        end
        raise ConversionError, invalid_png_message(command, error) if status.success?

        raise ConversionError, failed_conversion_message(command, error)
      rescue ProcessRunner::Error => e
        raise ConversionError, failed_conversion_message(command, e.message)
      end

      private

      def available_command(converter: DEFAULT_CONVERTER)
        self.class.available_command(converter: converter)
      end

      def executable?(command)
        self.class.send(:executable?, command)
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

        raise ArgumentError, "Unknown PNG converter: #{converter.inspect}. Available converters: #{CONVERTER_OPTIONS.join(', ')}"
      end

      def scaled_dimension(value, scale)
        scaled = value.to_f * scale
        return scaled.to_i if scaled == scaled.to_i

        scaled
      end

      def resolve_scale(scale)
        unless scale.is_a?(Numeric) && scale.finite? && scale.positive?
          raise ArgumentError, 'PNG scale must be a positive finite number'
        end

        scale.to_f
      end

      def scale_svg_dimensions(svg, scale)
        document = REXML::Document.new(svg)
        root = document.root
        view_box = root.attributes['viewBox'].to_s.split.map(&:to_f)
        logical_width = numeric_svg_dimension(root.attributes['width'], view_box[2])
        logical_height = numeric_svg_dimension(root.attributes['height'], view_box[3])
        root.attributes['width'] = scaled_dimension(logical_width, scale).to_s
        root.attributes['height'] = scaled_dimension(logical_height, scale).to_s
        document.to_s
      end

      def numeric_svg_dimension(value, fallback)
        dimension = Float(value)
        dimension.positive? ? dimension : fallback
      rescue ArgumentError, TypeError
        fallback
      end

      def self.paths
        ENV.fetch('PATH', '').split(File::PATH_SEPARATOR)
      end

      def missing_converter_message(converter)
        resolved_converter = self.class.resolve_converter(converter)
        required = if resolved_converter == :auto
                     'rsvg-convert, magick, or convert'
                   else
                     CONVERTER_COMMANDS[resolved_converter].first
                   end

        "PNG export requires #{required} to be installed. #{install_hint}"
      end

      def install_hint
        'Install hints: macOS: brew install librsvg or imagemagick; Debian/Ubuntu: apt install librsvg2-bin or imagemagick; Windows: install ImageMagick.'
      end

      def failed_conversion_message(command, error)
        detail = error.to_s.strip
        detail = 'unknown error' if detail.empty?

        "Failed to convert SVG to PNG using #{command.first}: #{detail}"
      end

      def invalid_png_message(command, error)
        detail = error.to_s.strip
        return "Failed to convert SVG to PNG using #{command.first}: converter did not produce PNG data" if detail.empty?

        "Failed to convert SVG to PNG using #{command.first}: converter did not produce PNG data (#{detail})"
      end
    end
  end
end
