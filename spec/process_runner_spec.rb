# frozen_string_literal: true

require 'graphomaton'
require 'rbconfig'
require 'tmpdir'

RSpec.describe Graphomaton::ProcessRunner do
  it 'captures stdout, stderr, and exit status' do
    stdout, stderr, status = described_class.capture3(
      RbConfig.ruby,
      '-e',
      'STDOUT.write(STDIN.read.upcase); STDERR.write("notice")',
      stdin_data: 'hello'
    )

    expect(stdout).to eq('HELLO')
    expect(stderr).to eq('notice')
    expect(status).to be_success
  end

  it 'finds executables by PATH, explicit path, and Windows executable extensions' do
    Dir.mktmpdir do |directory|
      executable = File.join(directory, 'renderer')
      windows_executable = File.join(directory, 'renderer.EXE')
      File.write(executable, '')
      File.write(windows_executable, '')
      File.chmod(0o755, executable)
      File.chmod(0o755, windows_executable)

      if Gem.win_platform?
        expect(described_class.which('renderer', path: directory, pathext: '.EXE;.CMD')).to eq(windows_executable)
        expect(described_class.which(windows_executable, path: '')).to eq(windows_executable)
      else
        expect(described_class.which('renderer', path: directory)).to eq(executable)
        expect(described_class.which(executable, path: '')).to eq(executable)

        allow(Gem).to receive(:win_platform?).and_return(true)
        expect(described_class.which('renderer', path: directory, pathext: '.EXE;.CMD')).to eq(windows_executable)
        expect(described_class.which(executable, path: '', pathext: '.EXE;.CMD')).to eq(windows_executable)
      end
    end
  end

  it 'terminates processes that exceed the timeout' do
    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    3.times do
      expect do
        described_class.capture3(RbConfig.ruby, '-e', 'sleep 5', timeout: 0.1)
      end.to raise_error(described_class::TimeoutError, /timed out/)
    end

    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at
    expect(elapsed).to be < 1.0
  end

  it 'terminates descendants after their parent exits' do
    skip 'fork is unavailable on Windows' if Gem.win_platform?

    Dir.mktmpdir do |directory|
      pid_path = File.join(directory, 'child.pid')
      term_path = File.join(directory, 'child.term')
      script = <<~RUBY
        fork do
          trap('TERM') { File.write(ARGV.fetch(1), 'terminated'); exit! }
          File.write(ARGV.fetch(0), Process.pid)
          sleep 5
        end
        exit!
      RUBY
      child_pid = nil

      begin
        expect do
          described_class.capture3(RbConfig.ruby, '-e', script, pid_path, term_path, timeout: 0.2)
        end.to raise_error(described_class::TimeoutError, /timed out/)
        child_pid = Integer(File.read(pid_path), 10)
        expect(File.read(term_path)).to eq('terminated')
      ensure
        begin
          Process.kill('KILL', child_pid) if child_pid
        rescue Errno::ESRCH
          nil
        end
      end
    end
  end

  it 'terminates processes whose output exceeds the limit' do
    expect do
      described_class.capture3(
        RbConfig.ruby,
        '-e',
        'STDOUT.write("x" * 1024 * 1024)',
        max_stdout_bytes: 128
      )
    end.to raise_error(described_class::OutputLimitError, /stdout exceeded 128 bytes/)
  end
end
