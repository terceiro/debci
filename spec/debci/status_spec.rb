require 'debci/status'

require 'json'
require 'stringio'

describe Debci::Status do

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
      @status = Debci::Status.from_file('/path/to/status.json')
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
  end

  it('ignores invalid date') do
    status_file('invalid.json', { "date" => "foobar" })
    status = Debci::Status.from_file('invalid.json')
    expect(status.date).to be_nil
  end

  context 'invalid input' do
    before(:each) do
      status_file('invalid.json', { "date" => "INVALID", "duration_seconds" => "INVALID" })
      @status = Debci::Status.from_file('invalid.json')
    end

    it('ignores invalid date') { expect(@status.date).to be_nil }
    it('ignores invalid duration') { expect(@status.duration_seconds).to be_nil }
  end

  def status_file(filename, data)
    io = StringIO.new(JSON.dump(data))
    File.stub(:exists?).with(filename).and_return(true)
    File.stub(:open).with(filename, 'r').and_yield(io)
  end

end
