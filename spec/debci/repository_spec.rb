require 'debci/repository'

require 'tmpdir'
require 'fileutils'
require 'json'

describe Debci::Repository do

  before(:all) do
    @now = Time.now.strftime('%Y%m%d_%H%M%S')

    @datadir = Dir.mktmpdir
    mkdir_p 'packages/unstable/amd64/r/rake'
    mkdir_p 'packages/unstable/i386/r/rake'
    mkdir_p 'packages/testing/amd64/r/rake'
    mkdir_p 'packages/testing/i386/r/rake'

    mkdir_p 'packages/unstable/amd64.old'

    past_status 'packages/unstable/amd64/r/rake', { 'status' => 'pass', 'previous_status' => 'fail' }, '20140412_212642'
    latest_status 'packages/unstable/amd64/r/rake', { 'status' => 'fail', 'previous_status' => 'pass' }
    latest_status 'packages/testing/amd64/r/rake', { 'status' => 'fail', 'previous_status' => 'pass'}

    history 'packages/unstable/amd64/r/rake', [{'status' => 'fail', 'date' => '2014-08-01 11:11:12'},
                                               {'status' => 'pass', 'date' => '2014-07-07 12:12:15'},
                                               {'status' => 'tmpfail', 'date' => '2014-03-01 14:15:30'}]

    mkdir_p 'packages/unstable/amd64/r/rake-compiler'
    mkdir_p 'packages/unstable/i386/r/rake-compiler'
    mkdir_p 'packages/testing/amd64/r/rake-compiler'
    mkdir_p 'packages/testing/i386/r/rake-compiler'

    mkdir_p 'packages/testing/i386/d/debci'

    mkdir_p 'packages/unstable/amd64/r/ruby-ffi'
    mkdir_p 'packages/unstable/i386/r/ruby-ffi'
    mkdir_p 'packages/testing/amd64/r/ruby-ffi'
    mkdir_p 'packages/testing/i386/r/ruby-ffi'

    latest_status 'packages/unstable/amd64/r/ruby-ffi', {'status' => 'tmpfail',
                                                         'previous_status' => 'pass' }

    mkdir_p 'packages/unstable/amd64/r/rubygems-integration'
    mkdir_p 'packages/unstable/i386/r/rubygems-integration'
    mkdir_p 'packages/testing/amd64/r/rubygems-integration'
    mkdir_p 'packages/testing/i386/r/rubygems-integration'
  end

  attr_reader :now

  after(:all) do
    FileUtils.rm_rf @datadir
  end

  def mkdir_p(path)
    FileUtils.mkdir_p(File.join@datadir, path)
  end

  def past_status(path, data, run_id)
    File.open(File.join(@datadir, path, run_id + '.json'), 'w') do |f|
      f.write(JSON.dump({ 'run_id' => run_id }.merge(data)))
    end
  end

  def history(path, data)
    File.open(File.join(@datadir, path, 'history.json'), 'w') do |f|
      f.write(JSON.pretty_generate(data))
    end
  end

  def latest_status(path, data)
    run_id = now
    past_status(path, data, run_id)
    Dir.chdir(File.join(@datadir, path)) do
      FileUtils.ln_s(run_id + '.json', 'latest.json')
    end
  end

  let(:repository) { Debci::Repository.new(@datadir) }

  it 'knows about architectures' do
    expect(repository.architectures).to eq(['amd64', 'i386'])
  end

  it 'knows about suites' do
    expect(repository.suites).to eq(['testing', 'unstable'])
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
    expect(lambda { repository.find_package('doesnotexist') }).to raise_error(Debci::Repository::PackageNotFound)
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
      expect(['unstable', 'testing']).to include(s.suite)
      expect(['amd64', 'i386']).to include(s.architecture)
    end
  end

  it 'fetches news for packages' do
    statuses = repository.news_for('rake')
    expect(statuses.length).to eq(3)
    statuses.each do |s|
      expect(s).to be_a(Debci::Status)
      expect(['unstable', 'testing']).to include(s.suite)
      expect(['amd64', 'i386']).to include(s.architecture)
    end
  end

  it 'limits number of news' do
    statuses = repository.news_for('rake', 2)
    expect(statuses.length).to eq(2)
  end

  it 'sorts news with most recent first' do
    glob = File.join(@datadir, 'packages/{unstable}/{amd64}/r/rake/[0-9]*.json')
    statuses_reversed = Dir.glob(glob).sort_by { |f| File.basename(f) }.reverse

    expect(repository).to receive(:architectures).and_return(['amd64'])
    expect(repository).to receive(:suites).and_return(['unstable'])
    expect(Dir).to receive(:glob).with(glob).and_return(statuses_reversed)

    news = repository.news_for('rake')

    expect(news.first.run_id).to eq(now)
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

  it 'knows which packages are temporarily failing' do
    tmpfail_packages = repository.tmpfail_packages

    expect(tmpfail_packages).to be_a(Array)
    expect(tmpfail_packages.length).to eq(1)

    tmpfail_packages.each do |package|
      expect(package).to be_a(Debci::Package)
      expect(package.name).to eq('ruby-ffi')

      package.status.flatten.each do |p|
        expect([:tmpfail, :no_test_data]).to include(p.status)
      end
    end
  end
end
