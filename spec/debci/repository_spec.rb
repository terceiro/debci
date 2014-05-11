require 'debci/repository'

require 'tmpdir'
require 'fileutils'
require 'json'

describe Debci::Repository do

  before(:all) do
    @now = Time.now.strftime('%Y%m%d_%H%M%S')

    @datadir = '/tmp/foobar' # Dir.mktmpdir
    mkdir_p 'unstable-amd64/packages/r/rake'
    mkdir_p 'unstable-i386/packages/r/rake'
    mkdir_p 'testing-amd64/packages/r/rake'
    mkdir_p 'testing-i386/packages/r/rake'

    mkdir_p 'unstable-amd64.old'

    past_status 'unstable-amd64/packages/r/rake', { 'status' => 'pass', 'previous_status' => 'fail' }, '20140412_212642'
    latest_status 'unstable-amd64/packages/r/rake', { 'status' => 'fail', 'previous_status' => 'pass' }
    latest_status 'testing-amd64/packages/r/rake', { 'status' => 'fail', 'previous_status' => 'pass'}

    mkdir_p 'unstable-amd64/packages/r/rake-compiler'
    mkdir_p 'unstable-i386/packages/r/rake-compiler'
    mkdir_p 'testing-amd64/packages/r/rake-compiler'
    mkdir_p 'testing-i386/packages/r/rake-compiler'

    mkdir_p 'testing-i386/packages/d/debci'

    mkdir_p 'unstable-amd64/packages/r/ruby-ffi'
    mkdir_p 'unstable-i386/packages/r/ruby-ffi'
    mkdir_p 'testing-amd64/packages/r/ruby-ffi'
    mkdir_p 'testing-i386/packages/r/ruby-ffi'

    mkdir_p 'unstable-amd64/packages/r/rubygems-integration'
    mkdir_p 'unstable-i386/packages/r/rubygems-integration'
    mkdir_p 'testing-amd64/packages/r/rubygems-integration'
    mkdir_p 'testing-i386/packages/r/rubygems-integration'
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
      f.write(JSON.dump(data))
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
    expect(repository.suites).to eq(['unstable', 'testing'])
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

  it 'supports the Package class' do
    package = repository.find_package('rake')
    package.suites
    package.architectures
    package.status
    package.news
  end

end
