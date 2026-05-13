# frozen_string_literal: true

require 'graphomaton'

RSpec.describe Graphomaton::Exporters::Png do
  let(:automaton) { Graphomaton.new }
  let(:png_exporter) { described_class.new(automaton) }
  let(:command) { ['rsvg-convert', '--format', 'png', '-'] }
  let(:magick_command) { ['magick', 'svg:-', 'png:-'] }
  let(:png_data) { described_class::PNG_SIGNATURE + 'png-data'.b }
  let(:successful_status) { instance_double(Process::Status, success?: true) }
  let(:failed_status) { instance_double(Process::Status, success?: false) }

  before do
    automaton.add_state('A')
    automaton.add_state('B')
    automaton.add_transition('A', 'B', 'go')
  end

  describe '#initialize' do
    it 'initializes with an automaton' do
      expect(png_exporter).to be_a(described_class)
    end
  end

  describe '.available?' do
    it 'returns true when a converter command is available' do
      allow(described_class).to receive(:available_command).and_return(command)

      expect(described_class.available?).to be true
    end

    it 'returns false when no converter command is available' do
      allow(described_class).to receive(:available_command).and_return(nil)

      expect(described_class.available?).to be false
    end

    it 'checks a specific converter when requested' do
      allow(described_class).to receive(:available_command).with(converter: :magick).and_return(magick_command)

      expect(described_class.available?(converter: :magick)).to be true
    end
  end

  describe '#export' do
    before do
      allow(png_exporter).to receive(:available_command).and_return(command)
    end

    it 'returns PNG bytes converted from SVG' do
      expect(Open3).to receive(:capture3)
        .with(*command, stdin_data: a_string_including('<svg'), binmode: true)
        .and_return([png_data, '', successful_status])

      expect(png_exporter.export).to eq(png_data)
    end

    it 'uses a requested converter command' do
      expect(png_exporter).to receive(:available_command).with(converter: :magick).and_return(magick_command)
      expect(Open3).to receive(:capture3)
        .with(*magick_command, stdin_data: a_string_including('<svg'), binmode: true)
        .and_return([png_data, '', successful_status])

      expect(png_exporter.export(converter: :magick)).to eq(png_data)
    end

    it 'passes custom dimensions to the SVG renderer' do
      expect(Open3).to receive(:capture3) do |*args|
        options = args.last
        expect(options[:stdin_data]).to include("width='1000'")
        expect(options[:stdin_data]).to include("height='800'")

        [png_data, '', successful_status]
      end

      png_exporter.export(1000, 800)
    end

    it 'scales SVG dimensions before PNG conversion' do
      expect(Open3).to receive(:capture3) do |*args|
        options = args.last
        expect(options[:stdin_data]).to include("width='2000'")
        expect(options[:stdin_data]).to include("height='1600'")

        [png_data, '', successful_status]
      end

      png_exporter.export(1000, 800, scale: 2.0)
    end

    it 'passes custom themes to the SVG renderer' do
      expect(Open3).to receive(:capture3) do |*args|
        options = args.last
        expect(options[:stdin_data]).to include('diagram-background')
        expect(options[:stdin_data]).to include('#111827')

        [png_data, '', successful_status]
      end

      png_exporter.export(theme: :dark)
    end

    it 'raises a conversion error when no converter is available' do
      allow(png_exporter).to receive(:available_command).and_return(nil)

      expect { png_exporter.export }.to raise_error(
        described_class::ConversionError,
        /requires rsvg-convert, magick, or convert.*brew install librsvg/
      )
    end

    it 'raises a conversion error when a requested converter is unavailable' do
      allow(png_exporter).to receive(:available_command).with(converter: :magick).and_return(nil)

      expect { png_exporter.export(converter: :magick) }.to raise_error(
        described_class::ConversionError,
        /requires magick to be installed/
      )
    end

    it 'raises a conversion error when the converter fails' do
      allow(Open3).to receive(:capture3).and_return(['', 'bad svg', failed_status])

      expect { png_exporter.export }.to raise_error(
        described_class::ConversionError,
        /Failed to convert SVG to PNG using rsvg-convert: bad svg/
      )
    end

    it 'raises a conversion error when the converter output is not PNG data' do
      allow(Open3).to receive(:capture3).and_return(['', '', successful_status])

      expect { png_exporter.export }.to raise_error(
        described_class::ConversionError,
        /converter did not produce PNG data/
      )
    end
  end
end
