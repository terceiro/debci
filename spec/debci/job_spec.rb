require 'spec_helper'

require 'debci/job'

describe Debci::Job do

  it 'sets created_at' do
    job = Debci::Job.create
    expect(job.created_at).to_not be_nil
  end
  it 'sets updated_at' do
    job = Debci::Job.create
    job.save!
    expect(job.updated_at).to_not be_nil
  end

  it 'escapes trigger' do
    job = Debci::Job.new(trigger: 'foo bar')
    expect(job.get_enqueue_parameters).to_not include('trigger:foo bar')
    expect(job.get_enqueue_parameters).to include('trigger:foo+bar')
  end

  [
    'áéíóú',
    '`cat /etc/passwd`',
    '$(cat /etc/passwd)',
    "a\nb",
  ].each do |invalid|
    it('escapes \"%s" in trigger' % invalid) do
      job = Debci::Job.new(trigger: invalid)
      expect(job.get_enqueue_parameters).to_not include(invalid)
    end
  end

  let(:suite) { 'unstable' }
  let(:arch) { 'amd64'}

  it 'imports status file' do
    job = Debci::Job.create(suite: suite, arch: arch)
    file = Tempfile.new('foo')
    file.write(
      {
        'run_id': job.run_id,
        'status': 'pass',
        'version': '1.0-1',
      }.to_json
    )
    file.close

    imported = Debci::Job.import(file.path, suite, arch)
    expect(imported).to eq(job)

    job.reload
    expect(job.status).to eq('pass')
    expect(job.version).to eq('1.0-1')
  end

end
