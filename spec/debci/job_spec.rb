require 'spec_helper'
require 'tempfile'

require 'debci/job'
require 'debci/package'

describe Debci::Job do
  include_context 'tmpdir'

  let(:package) { Debci::Package.create!(name: 'mypackage') }
  let(:new_job) { Debci::Job.create!(package: package) }

  it 'sets created_at' do
    expect(new_job.created_at).to_not be_nil
  end

  it 'sets updated_at' do
    new_job.save!
    expect(new_job.updated_at).to_not be_nil
  end

  it 'lists pending jobs' do
    job = new_job
    expect(Debci::Job.pending).to include(job)
  end

  it 'sorts pending jobs with older first' do
    yesterday = Time.now - 1.day
    job1 = Debci::Job.create(package: package, created_at: Time.now)
    job0 = Debci::Job.create(package: package, created_at: yesterday)

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
    job = Debci::Job.create(package: package, suite: suite, arch: arch)
    file = Tempfile.new('foo')
    file.write(
      {
        'package': package.name,
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

    imported = Debci::Job.import(file.path)
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
    job = Debci::Job.create(package: package, suite: suite, arch: arch)
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

    expect(-> { Debci::Job.import(file.path) }).to raise_error(Debci::Job::InvalidStatusFile)
    job.reload
    expect(job.status).to be_nil
  end

  it 'takes ridiculously large version numbers' do
    v = '1.' * 100 + '0'
    Debci::Job.create!(package: package, version: v)
  end

  context "history" do
    before(:each) do
      # latest job created first on purpose, to check ordering by date
      @job2 = Debci::Job.create(
        package: package,
        suite: 'testing',
        arch: 'amd64',
        status: 'pass',
        date: '2019-02-02 11:00'
      )
      @job1 = Debci::Job.create(
        package: package,
        suite: 'testing',
        arch: 'amd64',
        status: 'pass',
        date: '2019-02-01 11:00'
      )
      # pending/unfinished job
      @job3 = Debci::Job.create(
        package: package,
        suite: 'testing',
        arch: 'amd64',
      )
      # migration test
      @job4 = Debci::Job.create(
        package: package,
        suite: 'testing',
        arch: 'amd64',
        status: 'fail',
        date: '2019-02-03 11:00',
        trigger: 'bar/1.1-1',
        pin_packages: [['src:bar', 'unstable']]
      )

      @history = Debci::Job.history(package, 'testing', 'amd64')
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
      job = Debci::Job.new(package: package, duration_seconds: 65)
      expect(job.as_json["duration_human"]).to be_a(String)
    end
  end

  context 'converting to string' do
    let(:job) { Debci::Job.new(package: package, suite: 'testing', arch: 'amd64') }
    it 'uses status' do
      job.status = 'pass'
      expect(job.to_s).to eq('mypackage testing/amd64 (pass)')
    end
    it 'uses pending as status when status is nil' do
      expect(job.to_s).to eq('mypackage testing/amd64 (pending)')
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
        package: package,
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
      received = Pathname(Debci.config.autopkgtest_basedir) / "unstable/amd64/m/mypackage" / id
      expect(received).to exist
      expect(Pathname(incoming)).to_not exist
    end

    it 'compresses artifacts' do
      id = job.id.to_s
      received = Pathname(Debci.config.autopkgtest_basedir) / "unstable/amd64/m/mypackage" / id
      contents = received.children.map { |f| f.basename.to_s }.sort
      expect(contents).to eq(["artifacts.tar.gz", "log.gz"])
    end

    let(:second_original_job) do
      Debci::Job.create!(
        package: package,
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

    it 'records version as n/a if missing' do
      testpkg_version = Pathname(incoming) / 'testpkg-version'
      testpkg_version.unlink
      expect(job.version).to eq('n/a')
    end

    it 'cleans up upon request' do
      job.cleanup
      expect(job.autopkgtest_dir).to_not exist
      expect(job.debci_log).to_not exist
      expect(job.result_json).to_not exist
    end
  end

  context 'maintaining package status' do
    let(:data) do
      {
        package: package,
        suite: 'unstable',
        arch: 'amd64',
        status: 'pass',
        date: Time.now - 1.day,
      }
    end

    let(:first_job) do
      Debci::Job.create!(data)
    end

    let(:package_status) do
      Debci::PackageStatus.where(
        package: package,
        suite: 'unstable',
        arch: 'amd64'
      ).first
    end

    it 'creates package status' do
      job = first_job
      expect(package_status.job).to eq(job)
    end

    it 'updates package status when a new job arrives' do
      job = first_job
      new_job = Debci::Job.create!(data.merge(date: Time.now))
      job.save! # even if an earlier job is later modified
      expect(package_status.job).to eq(new_job)
    end

    it 'ignores unfinshed tests' do
      job = first_job
      Debci::Job.create!(data.merge(status: nil))
      Debci::Job.create!(data.merge(date: nil))
      expect(package_status.job).to eq(job)
    end

    it 'ignores migration tests' do
      job = first_job
      Debci::Job.create!(data.merge(date: Time.now, pin_packages: ['experimental', 'src:foobar']))
      expect(package_status.job).to eq(job)
    end
  end

  context 'getting status' do
    it 'picks finished jobs for status' do
      j1 = Debci::Job.create!(package: package, suite: 'unstable', arch: 'amd64', status: 'pass', date: Time.now - 1.day)
      j2 = Debci::Job.create!(package: package, suite: 'unstable', arch: 'i386', status: 'fail', date: Time.now - 1.day)
      j3 = Debci::Job.create!(package: package, suite: 'unstable', arch: 'amd64')

      s = Debci::Job.status_on('unstable', 'amd64')
      expect(s).to include(j1)
      expect(s).to_not include(j2)
      expect(s).to_not include(j3)
    end
  end

  context 'getting platform specific issues' do
    before(:each) do
      @pass = package.jobs.create!(date: Time.now, status: 'pass', suite: 'unstable', arch: 'amd64')
      @fail = package.jobs.create!(date: Time.now, status: 'fail', suite: 'unstable', arch: 'arm64')
    end
    it 'lists job that have different results on different architectures' do
      issues = Debci::Job.platform_specific_issues

      expect(issues[package]).to include(@pass)
      expect(issues[package]).to include(@fail)
    end

    it 'ignores packages without different results' do
      other_package = Debci::Package.create!(name: 'otherpackage')
      other_package.jobs.create!(date: Time.now, status: 'pass', suite: 'unstable', arch: 'amd64')
      other_package.jobs.create!(date: Time.now, status: 'pass', suite: 'unstable', arch: 'arm64')

      issues = Debci::Job.platform_specific_issues
      expect(issues).to_not include(other_package)
    end
  end

  it 'includes package name in JSON representation' do
    expect(new_job.as_json["package"]).to eq(package.name)
  end
end
