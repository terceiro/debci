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

  it 'returns the current/last value for a set of data' do
    expect(graph.current_value('date')).to eq(Time.parse('2014-08-15 01:30:15' + ' UTC'))
    expect(graph.current_value('pass')).to eq(200)
    expect(graph.current_value('fail')).to eq(150)
    expect(graph.current_value('tmpfail')).to eq(20)
    expect(graph.current_value('total')).to eq(370)
  end

  it 'returns the second to last value for a set of data' do
    expect(graph.previous_value('date')).to eq(Time.parse('2014-08-10 12:12:30' + ' UTC'))
    expect(graph.previous_value('pass')).to eq(100)
    expect(graph.previous_value('fail')).to eq(200)
    expect(graph.previous_value('tmpfail')).to eq(20)
    expect(graph.previous_value('total')).to eq(320)
  end

  it 'gets status history data' do
    expect(graph.pass).to include(100, 200)
    expect(graph.fail).to include(200, 150)
    expect(graph.tmpfail).to include(20, 20)
    expect(graph.total).to include(320, 370)
  end
end
