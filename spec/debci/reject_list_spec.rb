require "spec_helper"
require 'debci/reject_list'

describe Debci::RejectList do
  let(:reject_list) { Debci::RejectList.new }
  let(:reject_list_file) { File.join(Debci.config.config_dir, 'reject_list') }
  let(:blacklist_file) { File.join(Debci.config.config_dir, 'blacklist') }

  before(:each) do
    allow(Debci.config).to receive(:suite_list).and_return(%w[testing unstable])
    allow(Debci.config).to receive(:arch_list).and_return(%w[amd64 arm64])
  end

  it 'is empty if there is no rejectlist or blacklist' do
    allow(File).to receive(:exist?).with(reject_list_file).and_return(false)
    allow(File).to receive(:exist?).with(blacklist_file).and_return(false)
    expect(reject_list.packages).to be_empty
  end

  context 'when there is a rejectlist' do
    before(:each) do
      content = [
        "# bug #999\n",
        "foo\n",
        "bar unstable\n",
        "baz unstable\n",
        "baz testing amd64\n",
        "fox * * 1.0.1\n",
        "xyz-*\n",
        "pinpoint * * *\n"
      ]
      write_reject_list(content)
    end

    it 'includes packages in the rejectlist' do
      expect(reject_list.packages.include?('foo')).to be true
      expect(reject_list.packages.include?('uno')).to be false
    end

    it 'expands rejectlists in the context to the narrow context' do
      expect(reject_list.include?('foo', suite: 'testing', arch: 'amd64')).to be true
    end

    it 'rejectlists a package when direct match if found' do
      expect(reject_list.include?('foo')).to be true
      expect(reject_list.include?('pinpoint', suite: 'testing', arch: 'arm64', version: '1:0.1.8-2'))
        .to be true
    end

    it 'rejectlists by contracting wildcard' do
      expect(reject_list.include?('foo', suite: 'testing')).to be true
    end

    it 'rejectlists by expanding wildcard' do
      expect(reject_list.include?('fox', suite: 'testing', version: '1.0.1')).to be true
      expect(reject_list.include?('fox', suite: 'testing', version: '1.0-1')).to be false
      expect(reject_list.include?('baz', arch: 'amd64')).to be true
    end

    it 'does not rejectlist when match is not found' do
      expect(reject_list.include?('bar', suite: 'testing')).to be false
      expect(reject_list.include?('baz', arch: 'arm64')).to be false
    end

    it 'records comments as reasons for a given package' do
      expect(reject_list.comment('foo')).to eq("bug #999\n")
    end

    it 'applies wildcards to package name' do
      expect(reject_list.include?('xyz-abc')).to be true
    end

    it 'does not crash on nil input' do
      expect(reject_list.include?(nil)).to be false
    end
  end

  def write_reject_list(content)
    allow(File).to receive(:exist?).with(reject_list_file).and_return(true)
    allow(File).to receive(:readlines).with(reject_list_file).and_return(content)
  end
end
