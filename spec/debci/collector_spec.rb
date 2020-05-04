require 'spec_helper'
require 'debci/collector'

describe Debci::Collector do
  include_context 'tmpdir'
  let(:collector) { Debci::Collector.new }
  let(:package) { Debci::Package.create!(name: 'mypkg') }
  let(:job) do
    Debci::Job.create!(
      package: package,
      suite: 'unstable',
      arch: 'amd64',
      requestor: 'debci',
    )
  end

  let(:payload) do
    Dir.chdir('spec/debci/job_spec/autopkgtest-incoming') do
      IO.popen(['tar', '-czf', '-', '.', "--transform=s/^./#{job.run_id}/"]).read
    end
  end

  it 'receives payload, updates database and HTML' do
    expect(Debci::HTML).to receive(:update_package).with(package)
    collector.receive_payload(tmpdir, payload)
    job.reload
    expect(job.status).to eq('pass')
  end

  it 'handles empty payload' do
    collector.receive_payload(tmpdir, '')
  end

  it 'handles no payload' do
    collector.receive_payload(tmpdir, nil)
  end

  it 'handles missing directory' do
    collector.receive_payload('/path/to/unexistig/directory', payload)
  end

  it 'handles and empty results tarball' do
    empty_tarball = IO.popen(['tar', '-czf', '-', '-T', '/dev/null']).read
    collector.receive_payload(tmpdir, empty_tarball)
  end

  it 'handles invalid data' do
    expect(Debci).to receive(:run).with('tar', 'xaf', 'results.tar.gz').and_raise(Debci::CommandFailed)
    expect(Debci).to receive(:warn)
    collector.receive_payload(tmpdir, 'BLABLA')
  end
end
