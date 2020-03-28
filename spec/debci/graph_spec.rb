require "spec_helper"
require 'debci/graph'

require 'fileutils'
require 'json'

def generate_data_element(date, pass, fail, tmpfail, total)
  { 'date' => date, 'pass' => pass, 'fail' => fail, 'tmpfail' => tmpfail, 'total' => total }
end

describe Debci::Graph do
  include_context 'tmpdir'

  before(:each) do
    initial_date = Time.parse('2014-08-10 12:12:30 UTC')
    final_date = Time.parse('2014-08-15 01:30:15 UTC')
    data_element1 = generate_data_element(initial_date, 100, 200, 20, 320)
    data_element2 = generate_data_element(final_date, 200, 150, 20, 370)
    mkdir_p 'status/unstable/amd64'
    history 'status/unstable/amd64', [data_element1, data_element2]
  end

  def mkdir_p(path)
    FileUtils.mkdir_p(File.join(tmpdir, path))
  end

  def history(path, data)
    File.open(File.join(tmpdir, path, 'history.json'), 'w') do |f|
      f.write(JSON.pretty_generate(data))
    end
  end

  let(:repository) { Debci::Repository.new(tmpdir) }
  let(:graph) { Debci::Graph.new(repository, 'unstable', 'amd64') }

  it 'gets history snapshots as entries' do
    expect(graph.entries.size).to eq(2)
  end

  it 'reduces history do 101 entries' do
    initial_date = Time.parse('2014-08-10 12:12:30 UTC')
    data = (0..150).map do |i|
      generate_data_element(initial_date + 3600 * 24 * i, 100, 200, 20, 320)
    end
    history 'status/unstable/amd64', data

    expect(graph.entries.size).to eq(101)
    expect(Time.parse(graph.entries.first['date'])).to eq(initial_date)
    days = 150 * 24 * 3600
    expect(Time.parse(graph.entries.last['date'])).to eq(initial_date + days)
  end
end
