# frozen_string_literal: true

require 'graphomaton'
require 'rbconfig'

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

  it 'terminates processes that exceed the timeout' do
    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    expect do
      described_class.capture3(RbConfig.ruby, '-e', 'sleep 5', timeout: 0.1)
    end.to raise_error(described_class::TimeoutError, /timed out/)

    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at
    expect(elapsed).to be < 1.0
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
