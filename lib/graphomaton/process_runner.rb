# frozen_string_literal: true

require 'open3'
require 'timeout'

class Graphomaton
  class ProcessRunner
    class Error < StandardError; end
    class TimeoutError < Error; end
    class OutputLimitError < Error; end

    DEFAULT_TIMEOUT = 30
    DEFAULT_MAX_STDOUT_BYTES = 64 * 1024 * 1024
    DEFAULT_MAX_STDERR_BYTES = 1024 * 1024
    READ_SIZE = 16 * 1024

    def self.capture3(*command, stdin_data: '', binmode: false, timeout: DEFAULT_TIMEOUT,
                      max_stdout_bytes: DEFAULT_MAX_STDOUT_BYTES,
                      max_stderr_bytes: DEFAULT_MAX_STDERR_BYTES)
      validate_limit(timeout, 'timeout')
      validate_limit(max_stdout_bytes, 'max_stdout_bytes')
      validate_limit(max_stderr_bytes, 'max_stderr_bytes')

      spawn_options = Gem.win_platform? ? { new_pgroup: true } : { pgroup: true }
      stdout_data = nil
      stderr_data = nil
      status = nil

      Open3.popen3(*command, **spawn_options) do |stdin, stdout, stderr, wait_thread|
        streams = [stdin, stdout, stderr]
        streams.each(&:binmode) if binmode
        writer = input_writer(stdin, stdin_data)
        stdout_reader = output_reader(stdout, max_stdout_bytes, 'stdout')
        stderr_reader = output_reader(stderr, max_stderr_bytes, 'stderr')
        threads = [writer, stdout_reader, stderr_reader]

        begin
          Timeout.timeout(timeout, TimeoutError, "Process timed out after #{timeout} seconds") do
            writer.value
            stdout_data = stdout_reader.value
            stderr_data = stderr_reader.value
            status = wait_thread.value
          end
        rescue TimeoutError, OutputLimitError
          terminate(wait_thread)
          raise
        ensure
          streams.each { |stream| stream.close unless stream.closed? }
          threads.each do |thread|
            thread.kill if thread.alive?
            thread.join
          end
        end
      end

      [stdout_data, stderr_data, status]
    end

    def self.input_writer(stdin, data)
      Thread.new do
        Thread.current.report_on_exception = false
        begin
          stdin.write(data)
        rescue Errno::EPIPE, IOError
          nil
        ensure
          stdin.close unless stdin.closed?
        end
      end
    end
    private_class_method :input_writer

    def self.output_reader(stream, limit, name)
      Thread.new do
        Thread.current.report_on_exception = false
        output = String.new(encoding: Encoding::BINARY)

        begin
          loop do
            chunk = stream.readpartial(READ_SIZE)
            if output.bytesize + chunk.bytesize > limit
              raise OutputLimitError, "Process #{name} exceeded #{limit} bytes"
            end
            output << chunk
          end
        rescue EOFError, IOError
          output
        ensure
          stream.close unless stream.closed?
        end
      end
    end
    private_class_method :output_reader

    def self.terminate(wait_thread)
      return unless wait_thread.alive?

      signal_process(wait_thread.pid, 'TERM')
      return if wait_thread.join(0.25)

      signal_process(wait_thread.pid, 'KILL')
      wait_thread.join
    end
    private_class_method :terminate

    def self.signal_process(pid, signal)
      Process.kill(signal, Gem.win_platform? ? pid : -pid)
    rescue Errno::ESRCH, Errno::EINVAL, Errno::EPERM
      Process.kill(signal, pid)
    rescue Errno::ESRCH, Errno::ECHILD
      nil
    end
    private_class_method :signal_process

    def self.validate_limit(value, name)
      return if value.is_a?(Numeric) && value.finite? && value.positive?

      raise ArgumentError, "#{name} must be a positive finite number"
    end
    private_class_method :validate_limit
  end
end
