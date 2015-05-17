require 'debci/status'

require 'json'
require 'stringio'

describe Debci::Status do

  def from_file(file)
    status = Debci::Status.from_file(file, 'unstable', 'amd64')
  end

  context 'with good input' do
    before(:each) do
      status_file('/path/to/status.json', {
        "run_id" => "20140501_192327",
        "package" => "rake",
        "version" => "10.1.1-1",
        "date" => "2014-05-01 19:24:12",
        "status" => "pass",
        "blame" => ["foo 1.1", "bar 2.0"],
        "previous_status" => "pass",
        "duration_seconds" => "45",
        "duration_human" => "0h 0m 45s",
        "message" => "All tests passed"
      })
      @status = from_file('/path/to/status.json')
    end

    it('gets run_id') { expect(@status.run_id).to eq('20140501_192327') }
    it('gets package name') { expect(@status.package).to eq('rake') }
    it('gets version') { expect(@status.version).to eq('10.1.1-1') }
    it('gets date based on UTC') { expect(@status.date).to eq(Time.parse('2014-05-01 19:24:12 UTC')) }
    it('gets status') { expect(@status.status).to eq(:pass)}
    it('gets previous status') { expect(@status.previous_status).to eq(:pass)}
    it('gets duration in seconds') { expect(@status.duration_seconds).to eq(45)}
    it('gets duration human') { expect(@status.duration_human).to eq('0h 0m 45s') }
    it('gets message') { expect(@status.message).to eq("All tests passed") }
    it('gets blame') { expect(@status.blame).to eq(['foo 1.1', 'bar 2.0']) }
  end

  context 'with invalid JSON' do
    it 'does not crash' do
      broken_status_file("invalid.json")
      expect(from_file('invalid.json')).to be_a(Debci::Status)
    end
  end

  it('ignores invalid date') do
    status_file('invalid.json', { "date" => "foobar" })
    status = from_file('invalid.json')
    expect(status.date).to be_nil
  end

  context 'invalid input' do
    before(:each) do
      status_file('invalid.json', { "date" => "INVALID", "duration_seconds" => "INVALID" })
      @status = from_file('invalid.json')
    end

    it('ignores invalid date') { expect(@status.date).to be_nil }
    it('ignores invalid duration') { expect(@status.duration_seconds).to be_nil }
  end

  context 'no status file' do
    before(:each) do
      @status = from_file('does-not-exist.json')
    end
    it('Sets a status') { expect(@status.status).to eq(:no_test_data) }
  end

  context 'news' do
    it 'is newsworthy when going from pass to fail' do
      status = status_with(status: :fail, previous_status: :pass)
      expect(status).to be_newsworthy
    end

    it 'is newsworthy when going from fail to pass' do
      status = status_with(status: :pass, previous_status: :fail)
      expect(status).to be_newsworthy
    end

    it 'is not newsworthy when keeps passing' do
      status = status_with(status: :pass, previous_status: :pass)
      expect(status).to_not be_newsworthy
    end

    it 'is not newsworthiness when keeps failing' do
      status = status_with(status: :fail, previous_status: :fail)
      expect(status).to_not be_newsworthy
    end
  end

  context 'headline' do
    let(:status) do
      status_with(status: :pass, suite: 'unstable', architecture: 'amd64')
    end

    it 'includes suite in the headline' do
      expect(status.headline).to match('unstable')
    end
    it 'includes architecture in the headline' do
      expect(status.headline).to match('amd64')
    end
  end

  context 'title' do
    [:pass, :fail, :tmpfail, :no_test_data, :INVALID].each do |s|
      it "should have a title for #{s}" do
        expect(status_with(status: s).title).to be_a(String)
      end
    end
  end

  context 'unknown blame' do
    it 'is always an Array' do
      expect(status_with(blame: 'unknown').blame).to be_a(Array)
    end
  end

  context 'time' do
    time = Debci::Status.new

    it 'should return a time in days since an item\'s date' do
      time.date = Time.parse('2014-06-07 03:02:15')
      expect(time.time).to include('day(s)')
    end

    it 'should return a time in hours since an item\'s date' do
      time.date = Time.now - Random.rand(80000)
      expect(time.time).to include('hour(s)')
    end
  end

  def status_with(data)
    s = Debci::Status.new
    data.each do |k,v|
      s.send("#{k}=", v)
    end
    s
  end

  def status_file(filename, data)
    save_status_file(filename, JSON.dump(data))
  end

  def broken_status_file(filename)
    save_status_file(filename, "invalid JSON")
  end

  def save_status_file(filename, json)
    io = StringIO.new(json)
    expect(File).to receive(:exists?).with(filename).and_return(true)
    expect(File).to receive(:open).with(filename, 'r').and_yield(io)
  end

end
