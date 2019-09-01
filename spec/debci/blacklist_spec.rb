require 'debci/blacklist'

describe Debci::Blacklist do
  let(:blacklist) { Debci::Blacklist.new }
  let(:blacklist_file) { File.join(Debci.config.config_dir, 'blacklist') }

  before(:each) do
    allow(Debci.config).to receive(:suite_list).and_return(%w[testing unstable])
    allow(Debci.config).to receive(:arch_list).and_return(%w[amd64 arm64])
  end

  it 'is empty if there is not blacklist' do
    allow(File).to receive(:exist?).with(blacklist_file).and_return(false)
    expect(blacklist.packages).to be_empty
  end

  context 'when there is a blacklist' do
    before(:each) do
      content = [
        "# bug #999\n",
        "foo\n",
        "bar unstable\n",
        "baz unstable\n",
        "baz testing amd64\n",
        "fox * * 1.0.1\n"
      ]
      write_blacklist(content)
    end

    it 'includes packages in the blacklist' do
      expect(blacklist.packages.include?('foo')).to be true
      expect(blacklist.packages.include?('uno')).to be false
    end

    it 'blacklists a package when direct match if found' do
      expect(blacklist.include?('foo')).to be true
    end

    it 'blacklists by contracting wildcard' do
      expect(blacklist.include?('foo', suite: 'testing')).to be true
    end

    it 'blacklists by expanding wildcard' do
      expect(blacklist.include?('fox', suite: 'testing', version: '1.0.1')).to be true
      expect(blacklist.include?('fox', suite: 'testing', version: '1.0-1')).to be false
      expect(blacklist.include?('baz', arch: 'amd64')).to be true
    end

    it 'does not blacklist when match is not found' do
      expect(blacklist.include?('bar', suite: 'testing')).to be false
      expect(blacklist.include?('baz', arch: 'arm64')).to be false
    end

    it 'records comments as reasons for a given package' do
      expect(blacklist.comment('foo')).to eq("bug #999\n")
    end
  end

  def write_blacklist(content)
    allow(File).to receive(:exist?).with(blacklist_file).and_return(true)
    allow(File).to receive(:readlines).with(blacklist_file).and_return(content)
  end
end
