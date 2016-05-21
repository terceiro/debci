require 'debci/graph'

require 'fileutils'
require 'json'

describe Debci::Graph do

  before(:all) do
    @datadir = Dir.mktmpdir

    mkdir_p 'status/unstable/amd64'
    history 'status/unstable/amd64', [{'date' => '2014-08-10 12:12:30 UTC', 'pass' => 100, 'fail' => 200, 'tmpfail' => 20, 'total' => 320},
                                      {'date' => '2014-08-15 01:30:15 UTC', 'pass' => 200, 'fail' => 150, 'tmpfail' => 20, 'total' => 370}]
  end

  after(:all) do
    FileUtils.rm_rf @datadir
  end

  def mkdir_p(path)
    FileUtils.mkdir_p(File.join@datadir, path)
  end

  def history(path, data)
    File.open(File.join(@datadir, path, 'history.json'), 'w') do |f|
      f.write(JSON.pretty_generate(data))
    end
  end

  let(:repository) { Debci::Repository.new(@datadir) }
  let(:graph) { Debci::Graph.new(repository, 'unstable', 'amd64') }

  it 'gets history snapshots as entries' do
    expect(graph.entries.size).to eq(2)
  end

  it 'reduces history do 101 entries' do
    initial_date = Time.parse('2014-08-10 12:12:30 UTC')
    data = (0..150).map do |i|
      { 'date' => initial_date + 3600*24*i, 'pass' => 100, 'fail' => 200, 'tmpfail' => 20, 'total' => 320 }
    end
    history 'status/unstable/amd64', data

    expect(graph.entries.size).to eq(101)
    expect(Time.parse(graph.entries.first['date'])).to eq(initial_date)
    expect(Time.parse(graph.entries.last['date'])).to eq(initial_date + 150*24*3600)
  end
end
