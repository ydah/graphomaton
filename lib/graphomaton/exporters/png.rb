# frozen_string_literal: true

require 'open3'

require_relative 'svg'

class Graphomaton
  module Exporters
    class Png
      class ConversionError < StandardError; end

      PNG_SIGNATURE = "\x89PNG\r\n\x1A\n".b.freeze
      DEFAULT_SCALE = 1.0

      CONVERTER_COMMANDS = [
        ['rsvg-convert', '--format', 'png', '-'],
        ['magick', 'svg:-', 'png:-'],
        ['convert', 'svg:-', 'png:-']
      ].freeze

      def initialize(automaton)
        @automaton = automaton
      end

      def export(width = 800, height = 600, theme: Svg::DEFAULT_THEME, scale: DEFAULT_SCALE, **svg_options)
        command = available_command
        raise ConversionError, missing_converter_message unless command

        resolved_scale = [scale.to_f, 0.1].max
        svg = Svg.new(@automaton).export(
          scaled_dimension(width, resolved_scale),
          scaled_dimension(height, resolved_scale),
          theme: theme,
          **svg_options
        )
        png, error, status = Open3.capture3(*command, stdin_data: svg, binmode: true)
        png = png.b

        return png if status.success? && png.start_with?(PNG_SIGNATURE)
        raise ConversionError, invalid_png_message(command, error) if status.success?

        raise ConversionError, failed_conversion_message(command, error)
      end

      private

      def available_command
        CONVERTER_COMMANDS.find { |command| executable?(command.first) }
      end

      def executable?(command)
        paths.any? do |path|
          executable_path = File.join(path, command)
          File.file?(executable_path) && File.executable?(executable_path)
        end
      end

      def scaled_dimension(value, scale)
        scaled = value.to_f * scale
        return scaled.to_i if scaled == scaled.to_i

        scaled
      end

      def paths
        ENV.fetch('PATH', '').split(File::PATH_SEPARATOR)
      end

      def missing_converter_message
        'PNG export requires rsvg-convert, magick, or convert to be installed'
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
