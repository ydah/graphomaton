# frozen_string_literal: true

require 'graphomaton'

RSpec.describe Graphomaton::Exporters::Pdf do
  let(:automaton) { Graphomaton.new }
  let(:pdf_exporter) { described_class.new(automaton) }
  let(:command) { ['rsvg-convert', '--format', 'pdf', '-'] }
  let(:magick_command) { ['magick', 'svg:-', 'pdf:-'] }
  let(:pdf_data) { described_class::PDF_SIGNATURE + 'pdf-data' }
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
      allow(pdf_exporter).to receive(:available_command).and_return(command)
    end

    it 'returns PDF bytes converted from SVG' do
      expect(Open3).to receive(:capture3)
        .with(*command, stdin_data: a_string_including('<svg'), binmode: true)
        .and_return([pdf_data, '', successful_status])

      expect(pdf_exporter.export).to eq(pdf_data)
    end

    it 'uses a requested converter command' do
      expect(pdf_exporter).to receive(:available_command).with(converter: :magick).and_return(magick_command)
      expect(Open3).to receive(:capture3)
        .with(*magick_command, stdin_data: a_string_including('<svg'), binmode: true)
        .and_return([pdf_data, '', successful_status])

      expect(pdf_exporter.export(converter: :magick)).to eq(pdf_data)
    end

    it 'passes custom themes to the SVG renderer' do
      expect(Open3).to receive(:capture3) do |*args|
        options = args.last
        expect(options[:stdin_data]).to include('diagram-background')
        expect(options[:stdin_data]).to include('#111827')

        [pdf_data, '', successful_status]
      end

      pdf_exporter.export(theme: :dark)
    end

    it 'raises a conversion error when no converter is available' do
      allow(pdf_exporter).to receive(:available_command).and_return(nil)

      expect { pdf_exporter.export }.to raise_error(
        described_class::ConversionError,
        /requires rsvg-convert, magick, or convert.*brew install librsvg/
      )
    end

    it 'raises a conversion error when the converter fails' do
      allow(Open3).to receive(:capture3).and_return(['', 'bad svg', failed_status])

      expect { pdf_exporter.export }.to raise_error(
        described_class::ConversionError,
        /Failed to convert SVG to PDF using rsvg-convert: bad svg/
      )
    end

    it 'raises a conversion error when the converter output is not PDF data' do
      allow(Open3).to receive(:capture3).and_return(['', '', successful_status])

      expect { pdf_exporter.export }.to raise_error(
        described_class::ConversionError,
        /converter did not produce PDF data/
      )
    end
  end
end
