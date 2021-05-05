require 'spec_helper'
require 'debci/expiration'

describe Debci::Expiration do
  context 'command line' do
    it 'runs' do
      expect_any_instance_of(Debci::Expiration).to receive(:run)
      Debci::Expiration::CLI.new.start
    end
  end

  context 'expiring jobs' do
    include_context 'tmpdir'
    before(:each) do
      allow(Debci.config).to receive(:data_basedir).and_return(tmpdir)
      allow(Debci.config).to receive(:data_retention).and_return(30)
    end

    it 'expires jobs' do
      pkg = Debci::Package.create!(name: "pkg1")
      Debci::Job.create!(package: pkg, suite: 'unstable', arch: "amd64", date: Time.now - 31.days)
      expect_any_instance_of(Debci::Job).to receive(:cleanup)

      Debci::Expiration.new.run
    end
  end
end
