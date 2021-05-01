require "spec_helper"
require 'debci/package'

describe Debci::Package do
  let(:repository) { double }

  before(:each) do
    allow(Debci.config).to receive(:arch_list).and_return(%w[amd64 i386])
    allow(Debci.config).to receive(:suite_list).and_return(%w[testing unstable])
    allow(Debci.config).to receive(:backend_list).and_return(%w[lxc qemu])
  end

  let(:package) do
    Debci::Package.create!(name: 'rake').tap do |p|
      # pending
      p.jobs.create!(suite: 'unstable', arch: 'amd64')

      # finished
      p.jobs.create!(suite: 'unstable', arch: 'amd64', status: 'pass', previous_status: 'fail', date: Time.now)
      p.jobs.create!(suite: 'testing', arch: 'i386', status: 'fail', date: Time.now)
    end
  end

  it 'knows about status' do
    status = package.status
    expect([status[0][1].suite, status[0][1].arch, status[0][1].status]).to eq(['unstable', 'amd64', 'pass'])
    expect([status[1][0].suite, status[1][0].arch, status[1][0].status]).to eq(['testing', 'i386', 'fail'])
  end

  it 'knows about news' do
    expect(package.news.size).to eq(1)
  end

  it 'converts to string' do
    expect(String(package)).to eq(package.name)
  end

  it 'has a prefix' do
    expect(Debci::Package.new(name: 'rake').prefix).to eq('r')
  end

  it 'has a prefix (lib*)' do
    expect(Debci::Package.new(name: 'libreoffice').prefix).to eq('libr')
  end

  context 'finding packages by prefix' do
    before(:each) do
      @libssh = Debci::Package.create!(name: 'libssh')
      @lua = Debci::Package.create!(name: 'lua')
      @python = Debci::Package.create(name: 'python')
    end

    it 'handles p' do
      expect(Debci::Package.by_prefix('p')).to eq([@python])
    end

    it 'handles libs' do
      expect(Debci::Package.by_prefix('libs')).to eq([@libssh])
    end

    it 'handles l' do
      expect(Debci::Package.by_prefix('l')).to eq([@lua])
    end
  end

  it 'lists existing prefixes' do
    Debci::Package.create!(name: 'vim')
    Debci::Package.create!(name: 'nano')
    prefixes = Debci::Package.prefixes
    expect(prefixes).to include('v')
    expect(prefixes).to include('n')
  end

  it 'may be rejectlisted' do
    pkg = Debci::Package.new(name: 'mypkg')
    allow(Debci.reject_list).to receive(:include?).with('mypkg', {}).and_return(true)
    expect(pkg).to be_reject_listed
  end

  context 'validating package names' do
    %w[
      0ad
      foo
      foo-bar
      foo.bar
      foo+
      foo-1.0
      libfoo++
    ].each do |pkg|
      it "accepts #{pkg}" do
        expect(Debci::Package.new(name: pkg)).to be_valid
      end
    end

    %w[
      foo=bar
      foo~bar
      foo`bar`
      foo$(bar)
      --foo
    ].each do |pkg|
      it "rejects #{pkg}" do
        expect(Debci::Package.new(name: pkg)).to_not be_valid
      end
    end
  end

  context 'listing test history' do
    it 'orders by date' do
      job2 = package.jobs.finished.where(suite: 'unstable', arch: 'amd64').last
      job1 = package.jobs.create!(
        suite: 'unstable',
        arch: 'amd64',
        status: 'pass',
        previous_status: 'fail',
        date: Time.now - 1.day
      )
      expect(package.history('unstable', 'amd64').to_a).to eq([job1, job2])
    end
  end

  context 'validating backend field' do
    it 'it accepts only valid debci backend or nil value' do
      expect(Debci::Package.new(name: 'foo1')).to be_valid
      expect(Debci::Package.new(name: 'foo2', backend: 'lxc')).to be_valid
      expect(Debci::Package.new(name: 'foo3', backend: 'abc')).to_not be_valid
    end
  end
end
