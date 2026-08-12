# frozen_string_literal: true

require 'tempfile'

class Graphomaton
  class AtomicFile
    def self.write(filename, content, binary: false)
      destination = File.expand_path(filename)
      directory = File.dirname(destination)
      basename = File.basename(destination)

      Tempfile.create([".#{basename}", '.tmp'], directory, binmode: binary) do |temporary|
        temporary.binmode if binary
        temporary.write(content)
        temporary.flush
        temporary.fsync
        temporary.close
        File.rename(temporary.path, destination)
      end

      content.bytesize
    end
  end
end
