# frozen_string_literal: true

require 'open3'

require_relative 'svg'

class Graphomaton
  module Exporters
    class Pdf
      class ConversionError < StandardError; end

      PDF_SIGNATURE = '%PDF-'
      DEFAULT_CONVERTER = :auto

      CONVERTER_COMMANDS = {
        rsvg: ['rsvg-convert', '--format', 'pdf', '-'],
        magick: ['magick', 'svg:-', 'pdf:-'],
        convert: ['convert', 'svg:-', 'pdf:-']
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
        pdf, error, status = Open3.capture3(*command, stdin_data: svg, binmode: true)
        pdf = pdf.b

        return pdf if status.success? && pdf.start_with?(PDF_SIGNATURE)
        raise ConversionError, invalid_pdf_message(command, error) if status.success?

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

        raise ArgumentError, "Unknown PDF converter: #{converter.inspect}. Available converters: #{CONVERTER_OPTIONS.join(', ')}"
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

        "PDF export requires #{required} to be installed. #{install_hint}"
      end

      def install_hint
        'Install hints: macOS: brew install librsvg or imagemagick; Debian/Ubuntu: apt install librsvg2-bin or imagemagick; Windows: install ImageMagick.'
      end

      def failed_conversion_message(command, error)
        detail = error.to_s.strip
        detail = 'unknown error' if detail.empty?

        "Failed to convert SVG to PDF using #{command.first}: #{detail}"
      end

      def invalid_pdf_message(command, error)
        detail = error.to_s.strip
        return "Failed to convert SVG to PDF using #{command.first}: converter did not produce PDF data" if detail.empty?

        "Failed to convert SVG to PDF using #{command.first}: converter did not produce PDF data (#{detail})"
      end
    end
  end
end
