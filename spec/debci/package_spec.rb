require "spec_helper"
require 'debci/package'
require 'debci/status'

describe Debci::Package do
  let(:repository) { double }

  let(:package) do
    Debci::Package.new('rake', repository)
  end

  it 'queries repository for architectures' do
    expect(repository).to receive(:architectures_for).with(package).and_return(%w[amd64 i386])
    expect(package.architectures).to eq(%w[amd64 i386])
  end

  it 'queries repository for suites' do
    expect(repository).to receive(:suites_for).with(package).and_return(%w[unstable experimental])
    expect(package.suites).to eq(%w[unstable experimental])
  end

  it 'queries repository for status' do
    status = double
    expect(repository).to receive(:status_for).with(package).and_return(status)
    expect(package.status).to be(status)
  end

  it 'queries repository for news' do
    news = double
    expect(repository).to receive(:news_for).with(package).and_return(news)
    expect(package.news).to be(news)
  end

  it 'detects if it has failures and temporary failures' do
    status = Set.new

    tmpfail_status = Debci::Status.new
    tmpfail_status.suite = 'unstable'
    tmpfail_status.architecture = 'amd64'
    tmpfail_status.status = :tmpfail

    pass_status = Debci::Status.new
    pass_status.suite = 'unstable'
    pass_status.architecture = 'i386'
    pass_status.status = :pass

    fail_status = Debci::Status.new
    fail_status.suite = 'unstable'
    fail_status.architecture = 'i386'
    fail_status.status = :fail

    neutral_status = Debci::Status.new
    neutral_status.suite = 'unstable'
    neutral_status.architecture = 'i386'
    neutral_status.status = :neutral

    status << tmpfail_status << pass_status << fail_status << neutral_status

    allow(repository).to receive(:status_for).with(package).and_return(status)
    expect(package.status).to eq(status)

    expect(package.tmpfail).to eq([tmpfail_status])

    expect(package.failures).to eq([fail_status])

    expect(package.fail_or_neutral).to eq([fail_status, neutral_status])
  end

  it 'converts to string' do
    expect(String(package)).to eq(package.name)
  end

  it 'has a prefix' do
    expect(Debci::Package.new('rake').prefix).to eq('r')
  end

  it 'has a prefix (lib*)' do
    expect(Debci::Package.new('libreoffice').prefix).to eq('libr')
  end

  it 'may be blacklisted' do
    pkg = Debci::Package.new('mypkg')
    allow(Debci.blacklist).to receive(:include?).with('mypkg', {}).and_return(true)
    expect(pkg).to be_blacklisted
  end

  it 'might succeed or fail' do
    bundle = Debci::Package.new('bundle')
    git = Debci::Package.new('git')

    pass_status = Debci::Status.new
    pass_status.suite = 'unstable'
    pass_status.architecture = 'amd64'
    pass_status.status = :pass

    fail_status = Debci::Status.new
    fail_status.suite = 'testing'
    fail_status.architecture = 'amd64'
    fail_status.status = :fail

    bundle.repository = repository
    git.repository = repository

    allow(repository).to receive(:status_for).with(bundle)
                                             .and_return([pass_status, fail_status])

    allow(repository).to receive(:status_for).with(git)
                                             .and_return([fail_status])

    expect(bundle.had_success?).to be true
    expect(git.always_failing?).to be true
  end

  it 'has a last updated date' do
    pkg = Debci::Package.new('pkg')
    status = Set.new

    testing_status = Debci::Status.new
    testing_status.suite = 'testing'
    testing_status.date = Time.now

    unstable_status = Debci::Status.new
    unstable_status.suite = 'unstable'
    unstable_status.date = Time.now

    status << testing_status << unstable_status
    pkg.repository = repository

    allow(repository).to receive(:status_for).with(pkg).and_return(status)

    expect(pkg.last_updated_at).to be_a(Time)
  end
end
