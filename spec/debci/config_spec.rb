require "spec_helper"
require 'debci/config'

describe Debci::Config do
  let(:config) { Debci::Config.new }

  KEYS = Debci::Config.members

  before(:each) do
    @io = StringIO.new(KEYS.map { |k| "#{k}=value-of-#{k}\n" }.join)
    cmd = ['debci', 'config', *KEYS.map(&:to_s)]
    expect(IO).to receive(:popen).with(cmd).and_yield(@io)
  end

  KEYS.each do |key|
    if key =~ /_list$/
      it "knows about #{key}" do
        expect(config.send(key)).to be_a(Array)
      end
    elsif key == :quiet
      it "knows about #{key}" do
        expect(config.send(key)).to_not be_a(String)
      end
    else
      it "knows about #{key}" do
        expect(config.send(key)).to be_a(String)
      end
    end
    it "strips newlines off #{key}" do
      expect(config.send(key)).to_not end_with("\n")
    end
  end

  it 'reads entry set to empty string in config file as nil' do
    @io.reopen("data_basedir=/path/to/data\nartifacts_url_base=\n")
    expect(config.artifacts_url_base).to be_nil
    expect(config.data_basedir).to eq('/path/to/data')
  end

  it 'splits at the first equal sign only' do
    url = 'sqlite3:/path/to/db.sqlite3?timeout=5000'
    @io.reopen("database_url=#{url}\n")
    expect(config.database_url).to eq(url)
  end
end
