require 'debci/config'

describe Debci::Config do

  let(:config) { Debci::Config.new }

  KEYS = Debci::Config.members

  before(:each) do
    @io = StringIO.new(KEYS.map { |k| "#{k}=value-of-#{k}\n" }.join)
    expect(IO).to receive(:popen).with(['debci', 'config', *KEYS.map(&:to_s)]).and_yield(@io)
  end

  KEYS.each do |key|
    it "knows about #{key}" do
      expect(config.send(key)).to be_a(String)
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

end
