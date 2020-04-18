require 'spec_helper'
require 'debci/collector'

describe Debci::Collector do
  include_context 'tmpdir'
  it 'receives job data and updates HTML' do
    collector = Debci::Collector.new
    job = Debci::Job.new(
      package: 'mypkg',
      suite: 'unstable',
      arch: 'amd64',
      duration_seconds: 1,
    )
    expect(Debci::Job).to receive(:receive).with('/path/to/results').and_return(job)
    expect(Debci::HTML).to receive(:update_package).with('mypkg')
    collector.receive('/path/to/results')
  end
end
