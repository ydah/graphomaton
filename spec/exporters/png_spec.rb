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
      expect(Graphomaton::ProcessRunner).to receive(:capture3)
        .with(*command, stdin_data: a_string_including('<svg'), binmode: true, timeout: 30, max_stdout_bytes: 67_108_864)
        .and_return([png_data, '', successful_status])

      expect(png_exporter.export).to eq(png_data)
    end

    it 'uses a requested converter command' do
      expect(png_exporter).to receive(:available_command).with(converter: :magick).and_return(magick_command)
      expect(Graphomaton::ProcessRunner).to receive(:capture3)
        .with(*magick_command, stdin_data: a_string_including('<svg'), binmode: true, timeout: 30, max_stdout_bytes: 67_108_864)
        .and_return([png_data, '', successful_status])

      expect(png_exporter.export(converter: :magick)).to eq(png_data)
    end

    it 'passes timeout and output limits to the process runner' do
      expect(Graphomaton::ProcessRunner).to receive(:capture3)
        .with(*command, stdin_data: a_string_including('<svg'), binmode: true, timeout: 0.5, max_stdout_bytes: 1024)
        .and_return([png_data, '', successful_status])

      expect(png_exporter.export(timeout: 0.5, max_output_bytes: 1024)).to eq(png_data)
    end

    it 'reports process runner failures as conversion errors' do
      allow(Graphomaton::ProcessRunner).to receive(:capture3)
        .and_raise(Graphomaton::ProcessRunner::TimeoutError, 'Process timed out after 0.1 seconds')

      expect { png_exporter.export(timeout: 0.1) }
        .to raise_error(described_class::ConversionError, /timed out after 0.1 seconds/)
    end

    it 'passes custom dimensions to the SVG renderer' do
      expect(Graphomaton::ProcessRunner).to receive(:capture3) do |*args|
        options = args.last
        expect(options[:stdin_data]).to include("width='1000'")
        expect(options[:stdin_data]).to include("height='800'")

        [png_data, '', successful_status]
      end

      png_exporter.export(1000, 800)
    end

    it 'scales pixel dimensions without changing the logical viewBox' do
      expect(Graphomaton::ProcessRunner).to receive(:capture3) do |*args|
        options = args.last
        document = REXML::Document.new(options[:stdin_data])
        expect(document.root.attributes['width']).to eq('2000')
        expect(document.root.attributes['height']).to eq('1600')
        expect(document.root.attributes['viewBox']).to eq('0 0 1000 800')

        [png_data, '', successful_status]
      end

      png_exporter.export(1000, 800, scale: 2.0)
    end

    it 'keeps state geometry stable across output scales' do
      rendered_documents = []
      allow(Graphomaton::ProcessRunner).to receive(:capture3) do |*args|
        rendered_documents << REXML::Document.new(args.last[:stdin_data])
        [png_data, '', successful_status]
      end

      png_exporter.export(1000, 800, scale: 1.0)
      png_exporter.export(1000, 800, scale: 2.0)

      circles = rendered_documents.map { |document| REXML::XPath.first(document, '//circle[@class="state-circle"]') }
      expect(circles.map { |circle| circle.attributes['r'] }).to eq(%w[40.0 40.0])
      expect(circles.map { |circle| circle.attributes['cx'] }).to eq([circles.first.attributes['cx']] * 2)
    end

    it 'scales dimensions resolved by SVG auto sizing' do
      automaton.add_transition('A', 'A', 'a very long self loop label')

      expect(Graphomaton::ProcessRunner).to receive(:capture3) do |*args|
        document = REXML::Document.new(args.last[:stdin_data])
        view_box = document.root.attributes['viewBox'].split.map(&:to_f)

        expect(document.root.attributes['width'].to_f).to be_within(0.001).of(view_box[2] * 2)
        expect(document.root.attributes['height'].to_f).to be_within(0.001).of(view_box[3] * 2)
        [png_data, '', successful_status]
      end

      png_exporter.export(100, 100, auto_size: true, scale: 2)
    end

    it 'rejects invalid scales instead of coercing them' do
      expect { png_exporter.export(scale: 'large') }.to raise_error(ArgumentError, /positive finite number/)
      expect { png_exporter.export(scale: Float::INFINITY) }.to raise_error(ArgumentError, /positive finite number/)
      expect { png_exporter.export(scale: 0) }.to raise_error(ArgumentError, /positive finite number/)
    end

    it 'passes custom themes to the SVG renderer' do
      expect(Graphomaton::ProcessRunner).to receive(:capture3) do |*args|
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
      allow(Graphomaton::ProcessRunner).to receive(:capture3).and_return(['', 'bad svg', failed_status])

      expect { png_exporter.export }.to raise_error(
        described_class::ConversionError,
        /Failed to convert SVG to PNG using rsvg-convert: bad svg/
      )
    end

    it 'raises a conversion error when the converter output is not PNG data' do
      allow(Graphomaton::ProcessRunner).to receive(:capture3).and_return(['', '', successful_status])

      expect { png_exporter.export }.to raise_error(
        described_class::ConversionError,
        /converter did not produce PNG data/
      )
    end
  end
end
