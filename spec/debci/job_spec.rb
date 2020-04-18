require 'spec_helper'
require 'tempfile'

require 'debci/job'

describe Debci::Job do
  include_context 'tmpdir'

  it 'sets created_at' do
    job = Debci::Job.create
    expect(job.created_at).to_not be_nil
  end
  it 'sets updated_at' do
    job = Debci::Job.create
    job.save!
    expect(job.updated_at).to_not be_nil
  end

  it 'lists pending jobs' do
    job = Debci::Job.create
    expect(Debci::Job.pending).to include(job)
  end

  it 'sorts pending jobs with older first' do
    yesterday = Time.now - 1.day
    job1 = Debci::Job.create(created_at: Time.now)
    job0 = Debci::Job.create(created_at: yesterday)

    expect(Debci::Job.pending).to eq([job0, job1])
  end

  it 'escapes trigger' do
    job = Debci::Job.new(trigger: 'foo bar')
    expect(job.enqueue_parameters).to_not include('trigger:foo bar')
    expect(job.enqueue_parameters).to include('trigger:foo+bar')
  end

  [
    'áéíóú',
    '`cat /etc/passwd`',
    '$(cat /etc/passwd)',
    "a\nb"
  ].each do |invalid|
    it('escapes \"%<invalid>s" in trigger' % { invalid: invalid }) do
      job = Debci::Job.new(trigger: invalid)
      expect(job.enqueue_parameters).to_not include(invalid)
    end
  end

  let(:suite) { 'unstable' }
  let(:arch) { 'amd64' }

  it 'imports status file' do
    job = Debci::Job.create(suite: suite, arch: arch)
    file = Tempfile.new('foo')
    file.write(
      {
        'run_id': job.run_id,
        'status': 'pass',
        'version': '1.0-1',
        'duration_seconds': 11,
        'date': '2018-09-09 20:40:00',
        'last_pass_date': '2018-01-09 20:40:00',
        'last_pass_version': '0.9-1',
        'message': 'bla bla bla',
        'previous_status': 'fail'
      }.to_json
    )
    file.close

    imported = Debci::Job.import(file.path, suite, arch)
    expect(imported).to eq(job)

    job.reload
    expect(job.status).to eq('pass')
    expect(job.version).to eq('1.0-1')
    expect(job.duration_seconds).to eq(11)
    expect(job.date).to eq(Time.utc(2018, 9, 9, 20, 40, 0))
    expect(job.last_pass_date).to eq(Time.utc(2018, 1, 9, 20, 40, 0))
    expect(job.last_pass_version).to eq('0.9-1')
    expect(job.message).to eq('bla bla bla')
    expect(job.previous_status).to eq('fail')
  end

  it 'refuses to import incorrect jobs' do
    job = Debci::Job.create(package: "foo", suite: suite, arch: arch)
    file = Tempfile.new('foo')
    file.write(
      {
        'package': 'bar',
        'run_id': job.run_id,
        'status': 'pass',
        'version': '1.0-1',
        'duration_seconds': 11,
        'date': '2018-09-09 20:40:00',
        'last_pass_date': '2018-01-09 20:40:00',
        'last_pass_version': '0.9-1',
        'message': 'bla bla bla',
        'previous_status': 'fail'
      }.to_json
    )
    file.close

    expect(-> { Debci::Job.import(file.path, suite, arch) }).to raise_error(Debci::Job::InvalidStatusFile)
    job.reload
    expect(job.status).to be_nil
  end

  it 'takes ridiculously large version numbers' do
    v = '1.' * 100 + '0'
    Debci::Job.create!(package: 'foo', version: v)
  end

  context "history" do
    before(:each) do
      # latest job created first on purpose, to check ordering by date
      @job2 = Debci::Job.create(
        package: 'foo',
        suite: 'testing',
        arch: 'amd64',
        status: 'pass',
        date: '2019-02-02 11:00'
      )
      @job1 = Debci::Job.create(
        package: 'foo',
        suite: 'testing',
        arch: 'amd64',
        status: 'pass',
        date: '2019-02-01 11:00'
      )
      # pending/unfinished job
      @job3 = Debci::Job.create(
        package: 'foo',
        suite: 'testing',
        arch: 'amd64',
      )
      # migration test
      @job4 = Debci::Job.create(
        package: 'foo',
        suite: 'testing',
        arch: 'amd64',
        status: 'fail',
        date: '2019-02-03 11:00',
        trigger: 'bar/1.1-1',
        pin_packages: [['src:bar', 'unstable']]
      )

      @history = Debci::Job.history('foo', 'testing', 'amd64')
    end

    it 'orders by date' do
      i1 = @history.index(@job1)
      i2 = @history.index(@job2)
      expect(i1).to be < i2
    end

    it 'does not include unfinished job' do
      expect(@history).to_not include(@job3)
    end

    it 'does not include jobs with pinned packages' do
      expect(@history).to_not include(@job3)
    end
  end

  context 'generating JSON' do
    it 'provides duration_human' do
      job = Debci::Job.new(duration_seconds: 65)
      expect(job.as_json["duration_human"]).to be_a(String)
    end
  end

  context 'converting to string' do
    let(:job) { Debci::Job.new(package: 'pkg', suite: 'testing', arch: 'amd64') }
    it 'uses status' do
      job.status = 'pass'
      expect(job.to_s).to eq('pkg testing/amd64 (pass)')
    end
    it 'uses pending as status when status is nil' do
      expect(job.to_s).to eq('pkg testing/amd64 (pending)')
    end
  end

  context 'mapping exit code to job status' do
    it('maps 0 to pass') { expect(Debci::Job.status(0)[0]).to eq('pass') }
    it('maps 2 to pass') { expect(Debci::Job.status(2)[0]).to eq('pass') }
    it('maps 4 to fail') { expect(Debci::Job.status(4)[0]).to eq('fail') }
    it('maps 6 to fail') { expect(Debci::Job.status(6)[0]).to eq('fail') }
    it('maps 8 to neutral') { expect(Debci::Job.status(8)[0]).to eq('neutral') }
    it('maps 12 to fail') { expect(Debci::Job.status(12)[0]).to eq('fail') }
    it('maps 14 to fail') { expect(Debci::Job.status(14)[0]).to eq('fail') }
    it('maps 16 to tmpfail') { expect(Debci::Job.status(16)[0]).to eq('tmpfail') }
    it('maps anything else to tmpfail') { expect(Debci::Job.status(99)[0]).to eq('tmpfail') }
  end

  context 'receiving autopkgtest results' do
    let(:original_job) do
      Debci::Job.create!(
        package: 'foobar',
        suite: 'unstable',
        arch: 'amd64',
        requestor: 'user'
      )
    end

    let(:incoming) do
      File.join(tmpdir, 'autopkgtest-incoming', original_job.id.to_s)
    end

    before(:each) do
      FileUtils.mkdir_p File.dirname(incoming)
      FileUtils.cp_r 'spec/debci/job_spec/autopkgtest-incoming', incoming
      allow_any_instance_of(Debci::Config).to receive(:autopkgtest_basedir).and_return(File.join(tmpdir, 'autopkgtest'))
    end
    let(:job) { Debci::Job.receive(incoming) }

    it('returns job instance') { expect(job.id).to eq(original_job.id) }
    it('gets status') { expect(job.status).to eq('pass') }
    it('gets message') { expect(job.message).to eq('All tests passed') }
    it('gets duration') { expect(job.duration_seconds).to eq(9) }
    it('gets date') { expect(job.date).to_not be_nil }
    it('gets version') { expect(job.version).to eq('1.0-1') }
    it 'moves directory into autopkgtest dir' do
      id = job.id.to_s
      received = Pathname(Debci.config.autopkgtest_basedir) / "unstable/amd64/f/foobar" / id
      expect(received).to exist
      expect(Pathname(incoming)).to_not exist
    end

    it 'compresses artifacts' do
      id = job.id.to_s
      received = Pathname(Debci.config.autopkgtest_basedir) / "unstable/amd64/f/foobar" / id
      contents = received.children.map { |f| f.basename.to_s }
      expect(contents).to eq(["artifacts.tar.gz", "log.gz"])
    end

    let(:second_original_job) do
      Debci::Job.create!(
        package: 'foobar',
        suite: 'unstable',
        arch: 'amd64',
        requestor: 'user'
      )
    end

    let(:second_job) do
      second_incoming = File.join(tmpdir, 'autopkgtest-incoming', second_original_job.id.to_s)
      FileUtils.cp_r 'spec/debci/job_spec/autopkgtest-incoming', second_incoming
      File.open(File.join(second_incoming, 'exitcode'), 'w') { |f| f.write('4') }
      File.open(File.join(second_incoming, 'testpkg-version'), 'w') { |f| f.write('foobar 99-1') }
      Debci::Job.receive(second_incoming)
    end

    it 'records previous_status' do
      first_job = job
      expect(second_job.status).to eq('fail')
      expect(second_job.previous_status).to eq(first_job.status)
    end

    it 'records last pass date and version' do
      first_job = job
      expect(second_job.last_pass_date).to be_within(0.0001).of(first_job.date)
      expect(second_job.last_pass_version).to eq(first_job.version)
    end
  end
end
