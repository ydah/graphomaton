# frozen_string_literal: true

require 'graphomaton'
require 'tmpdir'

RSpec.describe Graphomaton::AtomicFile do
  it 'atomically replaces text and binary files' do
    Dir.mktmpdir do |directory|
      text_path = File.join(directory, 'diagram.svg')
      binary_path = File.join(directory, 'diagram.png')

      expect(described_class.write(text_path, '<svg/>')).to eq(6)
      expect(described_class.write(binary_path, "\x89PNG".b, binary: true)).to eq(4)
      expect(File.read(text_path)).to eq('<svg/>')
      expect(File.binread(binary_path)).to eq("\x89PNG".b)
    end
  end

  it 'preserves the previous file when replacement fails' do
    Dir.mktmpdir do |directory|
      path = File.join(directory, 'diagram.svg')
      File.write(path, 'previous')
      allow(File).to receive(:rename).and_raise(Errno::EACCES)

      expect { described_class.write(path, 'replacement') }.to raise_error(Errno::EACCES)
      expect(File.read(path)).to eq('previous')
    end
  end

  it 'preserves the mode of an existing destination' do
    Dir.mktmpdir do |directory|
      path = File.join(directory, 'diagram.svg')
      File.write(path, 'previous')
      File.chmod(0o644, path)

      described_class.write(path, 'replacement')

      expect(File.stat(path).mode & 0o7777).to eq(0o644)
    end
  end

  it 'never replaces a file created during a no-clobber write' do
    Dir.mktmpdir do |directory|
      path = File.join(directory, 'diagram.svg')
      allow(File).to receive(:link).and_wrap_original do |original, source, destination|
        File.write(destination, 'competitor')
        original.call(source, destination)
      end

      expect { described_class.write(path, 'replacement', no_clobber: true) }.to raise_error(Errno::EEXIST)
      expect(File.read(path)).to eq('competitor')
    end
  end
end
