require 'debci/blacklist'

describe Debci::Blacklist do

  before(:each) do
    @tmpdir = Dir.mktmpdir
  end
  after(:each) do
    FileUtils.rm_rf(@tmpdir)
  end

  let(:blacklist) { Debci::Blacklist.new(@tmpdir) }

  it 'is empty if there is not blacklist' do
    expect(blacklist.packages).to be_empty
  end

  it 'includes packages in the blacklist' do
    write_blacklist("foo\nbar")
    expect(blacklist).to include('foo')
    expect(blacklist).to include('bar')
    expect(blacklist).to_not include('qux')
  end

  it 'records comments as reasons for a given package' do
    write_blacklist("# bug #999\nfoo")
    expect(blacklist.packages['foo']).to eq("bug #999\n")
  end

  def write_blacklist(content)
    File.open(File.join(@tmpdir, 'blacklist'), 'w') do |f|
      f.puts(content)
    end
  end

end
