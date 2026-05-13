# frozen_string_literal: true

require 'graphomaton'

RSpec.describe Graphomaton::Exporters::Webp do
  let(:automaton) { Graphomaton.new }
  let(:webp_exporter) { described_class.new(automaton) }
  let(:command) { ['magick', 'svg:-', 'webp:-'] }
  let(:convert_command) { ['convert', 'svg:-', 'webp:-'] }
  let(:webp_data) { "RIFF\x00\x00\x00\x00WEBPwebp-data".b }
  let(:successful_status) { instance_double(Process::Status, success?: true) }
  let(:failed_status) { instance_double(Process::Status, success?: false) }

  before do
    automaton.add_state('A')
    automaton.add_state('B')
    automaton.add_transition('A', 'B', 'go')
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
  end

  describe '#export' do
    before do
      allow(webp_exporter).to receive(:available_command).and_return(command)
    end

    it 'returns WebP bytes converted from SVG' do
      expect(Open3).to receive(:capture3)
        .with(*command, stdin_data: a_string_including('<svg'), binmode: true)
        .and_return([webp_data, '', successful_status])

      expect(webp_exporter.export).to eq(webp_data)
    end

    it 'uses a requested converter command' do
      expect(webp_exporter).to receive(:available_command).with(converter: :convert).and_return(convert_command)
      expect(Open3).to receive(:capture3)
        .with(*convert_command, stdin_data: a_string_including('<svg'), binmode: true)
        .and_return([webp_data, '', successful_status])

      expect(webp_exporter.export(converter: :convert)).to eq(webp_data)
    end

    it 'raises a conversion error when no converter is available' do
      allow(webp_exporter).to receive(:available_command).and_return(nil)

      expect { webp_exporter.export }.to raise_error(
        described_class::ConversionError,
        /requires magick or convert.*brew install imagemagick/
      )
    end

    it 'raises a conversion error when the converter fails' do
      allow(Open3).to receive(:capture3).and_return(['', 'bad svg', failed_status])

      expect { webp_exporter.export }.to raise_error(
        described_class::ConversionError,
        /Failed to convert SVG to WebP using magick: bad svg/
      )
    end

    it 'raises a conversion error when the converter output is not WebP data' do
      allow(Open3).to receive(:capture3).and_return(['', '', successful_status])

      expect { webp_exporter.export }.to raise_error(
        described_class::ConversionError,
        /converter did not produce WebP data/
      )
    end
  end
end
