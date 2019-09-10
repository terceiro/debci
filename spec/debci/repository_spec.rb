require 'debci'
require 'debci/repository'

require 'tmpdir'
require 'fileutils'
require 'json'

describe Debci::Repository do
  before(:all) do
    @datadir = Dir.mktmpdir
    mkdir_p 'packages/unstable/amd64/r/rake'
    mkdir_p 'packages/unstable/i386/r/rake'
    mkdir_p 'packages/testing/amd64/r/rake'
    mkdir_p 'packages/testing/i386/r/rake'

    mkdir_p 'packages/unstable/amd64.old'

    history 'packages/testing/amd64/r/rake', [
      { 'status' => 'fail', 'date' => '2014-08-01 11:11:12' },
      { 'status' => 'pass', 'date' => '2014-07-07 12:12:15' }
    ]

    history 'packages/unstable/amd64/r/rake', [
      { 'status' => 'fail', 'date' => '2014-08-01 11:11:12' },
      { 'status' => 'pass', 'date' => '2014-07-07 12:12:15' },
      { 'status' => 'tmpfail', 'date' => '2014-03-01 14:15:30' },
      { 'status' => 'fail', 'date' => '2015-03-01 14:15:30' },
      { 'status' => 'pass', 'date' => '2016-03-01 14:15:30' }
    ]

    mkdir_p 'packages/unstable/amd64/r/rake-compiler'
    mkdir_p 'packages/unstable/i386/r/rake-compiler'
    mkdir_p 'packages/testing/amd64/r/rake-compiler'
    mkdir_p 'packages/testing/i386/r/rake-compiler'

    mkdir_p 'packages/testing/i386/d/debci'

    mkdir_p 'packages/unstable/amd64/r/ruby-ffi'
    mkdir_p 'packages/unstable/i386/r/ruby-ffi'
    mkdir_p 'packages/testing/amd64/r/ruby-ffi'
    mkdir_p 'packages/testing/i386/r/ruby-ffi'

    latest_status 'packages/unstable/amd64/r/ruby-ffi', 'status' => 'tmpfail',
                                                        'previous_status' => 'pass'

    mkdir_p 'packages/unstable/amd64/r/rubygems-integration'
    mkdir_p 'packages/unstable/i386/r/rubygems-integration'
    mkdir_p 'packages/testing/amd64/r/rubygems-integration'
    mkdir_p 'packages/testing/i386/r/rubygems-integration'

    # platform specific issue
    latest_status 'packages/unstable/amd64/r/rubygems-integration',
                  'status' => 'pass',
                  'previous_status' => 'pass'
    latest_status 'packages/unstable/i386/r/rubygems-integration',
                  'status' => 'fail',
                  'previous_status' => 'fail'

    # NOT a platform specific issue - tmpfail should be ignored
    mkdir_p 'packages/unstable/amd64/r/racc'
    mkdir_p 'packages/unstable/i386/r/racc'
    latest_status 'packages/unstable/amd64/r/racc',
                  'status' => 'pass',
                  'previous_status' => 'pass'
    latest_status 'packages/unstable/i386/r/racc',
                  'status' => 'tmpfail',
                  'previous_status' => 'pass'

    mkdir_p 'packages/unstable/amd64/s/slowpackage'
    latest_status 'packages/unstable/amd64/s/slowpackage',
                  'status' => 'pass',
                  'duration_seconds' => 5000

    mkdir_p 'packages/unstable/amd64/n/newsworthypacakge'
    latest_status 'packages/unstable/amd64/n/newsworthypacakge',
                  'status' => 'pass',
                  'previous_status' => 'fail'
  end

  after(:all) do
    FileUtils.rm_rf @datadir
  end

  def mkdir_p(path)
    FileUtils.mkdir_p(File.join(@datadir, path))
  end

  def fetch_run_id
    @run_id ||= 0
    @run_id += 1
  end

  def history(path, data)
    previous_status = nil
    data.each do |entry|
      entry['run_id'] = fetch_run_id
      entry['previous_status'] = previous_status if previous_status
      previous_status = entry['status']
    end
    File.open(File.join(@datadir, path, 'history.json'), 'w') do |f|
      f.write(JSON.pretty_generate(data))
    end
  end

  def latest_status(path, data)
    package = File.basename(path)
    run_id = fetch_run_id
    File.open(File.join(@datadir, path, 'latest.json'), 'w') do |f|
      f.write(JSON.dump({ 'package' => package, 'run_id' => run_id }.merge(data)))
    end
  end

  let(:repository) { Debci::Repository.new(@datadir) }

  it 'knows about architectures' do
    expect(repository.architectures).to eq(%w[amd64 i386])
  end

  it 'knows about suites' do
    expect(repository.suites).to eq(%w[testing unstable])
  end

  it 'knows about prefixes' do
    expect(repository.prefixes).to include('d', 'r')
  end

  it 'knows about packages' do
    expect(repository.packages.sort).to include('debci', 'rake')
  end

  it 'knows about suites for a given package' do
    expect(repository.suites_for('rake')).to include('unstable', 'testing')
  end

  it 'knows about architectures for a given package' do
    expect(repository.architectures_for('rake')).to include('amd64', 'i386')
  end

  it 'fetches packages' do
    expect(repository.find_package('rake').name).to eq('rake')
  end

  it 'raises an exception when package is not found' do
    expect(-> { repository.find_package('doesnotexist') }).to raise_error(Debci::Repository::PackageNotFound)
  end

  it 'searches for packages with exact match' do
    expect(repository.search('rake').map(&:name)).to eq(['rake'])
  end

  it 'searches for packages' do
    expect(repository.search('ruby').map(&:name)).to include('ruby-ffi', 'rubygems-integration')
  end

  it 'fetches status for packages' do
    statuses = repository.status_for('rake')
    expect(statuses.length).to eq(2) # 2 suites
    expect(statuses.first.length).to eq(2) # 2 architectures
    statuses.flatten.each do |s|
      expect(s).to be_a(Debci::Status)
      expect(%w[unstable testing]).to include(s.suite)
      expect(%w[amd64 i386]).to include(s.architecture)
    end
  end

  it 'fetches blacklisted status for packages' do
    statuses = repository.all_status_for('rake')
    # Blacklisting testing_amd64, unstable_i386
    testing_amd64 = statuses.first.first
    unstable_i386 = statuses.second.second

    allow(testing_amd64).to receive(:blacklisted?).and_return(true)
    allow(unstable_i386).to receive(:blacklisted?).and_return(true)

    statuses = repository.blacklisted_status_for('rake')

    expect(statuses.length).to eq(2) # 2 suite
    statuses.flatten.each do |s|
      expect(s).to be_a(Debci::Status)
      expect([testing_amd64, unstable_i386]).to include(s)
    end
  end

  it 'fetches news for packages' do
    statuses = repository.news_for('rake')
    expect(statuses.length).to eq(3)
    statuses.each do |s|
      expect(s).to be_a(Debci::Status)
      expect(%w[unstable testing]).to include(s.suite)
      expect(%w[amd64 i386]).to include(s.architecture)
    end
  end

  it 'limits number of news' do
    statuses = repository.news_for('rake', 2)
    expect(statuses.length).to eq(2)
  end

  it 'sorts news with most recent first' do
    expect(repository).to receive(:architectures).and_return(['amd64'])
    expect(repository).to receive(:suites).and_return(['unstable'])
    news = repository.news_for('rake')

    first = news[0]
    second = news[1]
    expect(first.run_id).to be > second.run_id
  end

  it 'produces global news' do
    news = repository.global_news
    expect(news[0].package).to eq('newsworthypacakge')
  end

  it 'supports the Package class' do
    package = repository.find_package('rake')
    package.suites
    package.architectures
    package.status
    package.news
  end

  it 'iterates over all packages' do
    packages = []
    repository.each_package do |pkg|
      packages << pkg
    end

    expect(packages.map(&:class).uniq).to eq([Debci::Package])
  end

  it 'fetches status history for a package' do
    history = repository.history_for('rake', 'unstable', 'amd64')

    history.each do |item|
      expect(item).to be_a(Debci::Status)
      expect(item.status).to be_a(Object)
      expect(item.date).to be_a(Time)

      expect([:pass, :fail, :tmpfail]).to include(item.status)
    end
  end

  it 'sorts status history for a package by date in descending order' do
    history = repository.history_for('rake', 'unstable', 'amd64')

    expect(history.first.status).to eq(:pass)
    expect(history.first.date.to_s).to eq('2016-03-01 14:15:30 UTC')
    expect(history.last.status).to eq(:tmpfail)
    expect(history.last.date.to_s).to eq('2014-03-01 14:15:30 UTC')
  end

  it 'knows which packages are temporarily failing' do
    tmpfail_packages = repository.tmpfail_packages

    expect(tmpfail_packages).to be_a(Array)
    expect(tmpfail_packages.length).to be >= 1

    package = tmpfail_packages.find { |pkg| pkg.name == 'ruby-ffi' }
    expect(package).to be_a(Debci::Package)
    expect(package.name).to eq('ruby-ffi')

    package.status.flatten.each do |p|
      expect([:tmpfail, :no_test_data]).to include(p.status)
    end
  end

  it 'knows which packages are failing' do
    failing_packages = repository.failing_packages

    expect(failing_packages).to be_a(Array)
    expect(failing_packages.length).to be >= 1

    package = failing_packages.find { |pkg| pkg.name == 'rubygems-integration' }
    expect(package). to be_a(Debci::Package)
    expect(package.name). to eq('rubygems-integration')

    statuses = package.status.flatten.map(&:status)
    expect(statuses).to include(:fail)
  end

  it 'knows about slow-running tests' do
    slow = repository.slow_packages
    expect(slow).to be_a(Array)
    expect(slow.length).to be >= 1

    slow_status = slow.find { |status| status.package == 'slowpackage' }
    expect(slow_status).to be_a(Debci::Status)
  end

  it 'knows about platform-specific issues' do
    issues = repository.platform_specific_issues
    expect(issues).to have_key('rubygems-integration')
    expect(issues['rubygems-integration'].map(&:class).uniq).to eq([Debci::Status])
  end

  it 'does not consider tmpfail as a platform-specific issue' do
    issues = repository.platform_specific_issues
    expect(issues).to_not have_key('racc')
  end
end
