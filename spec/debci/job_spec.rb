require 'spec_helper'

require 'debci/job'

describe Debci::Job do

  it 'sets created_at' do
    job = Debci::Job.create
    expect(job.created_at).to_not be_nil
  end
  it 'sets created_at' do
    job = Debci::Job.create
    job.save!
    expect(job.updated_at).to_not be_nil
  end

  it 'escapes trigger' do
    job = Debci::Job.new(trigger: 'foo bar')
    expect(job.get_enqueue_parameters).to_not include('trigger:foo bar')
    expect(job.get_enqueue_parameters).to include('trigger:foo+bar')
  end

  [
    'áéíóú',
    '`cat /etc/passwd`',
    '$(cat /etc/passwd)',
    "a\nb",
  ].each do |invalid|
    it('escapes \"%s" in trigger' % invalid) do
      job = Debci::Job.new(trigger: invalid)
      expect(job.get_enqueue_parameters).to_not include(invalid)
    end
  end

end
