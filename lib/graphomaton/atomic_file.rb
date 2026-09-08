# frozen_string_literal: true

require 'tempfile'

class Graphomaton
  class AtomicFile
    def self.write(filename, content, binary: false, no_clobber: false)
      destination = File.expand_path(filename)
      directory = File.dirname(destination)
      basename = File.basename(destination)
      existing_mode = File.stat(destination).mode & 0o7777 if File.exist?(destination)

      Tempfile.create([".#{basename}", '.tmp'], directory, binmode: binary) do |temporary|
        temporary.binmode if binary
        temporary.chmod(existing_mode) if existing_mode
        temporary.write(content)
        temporary.flush
        temporary.fsync
        temporary.close
        if no_clobber
          File.link(temporary.path, destination)
        else
          File.rename(temporary.path, destination)
        end
      end

      content.bytesize
    end
  end
end
