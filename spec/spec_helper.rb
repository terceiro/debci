if ENV["COVERAGE"] != "no"
  require 'simplecov'
  SimpleCov.start do
    minimum_coverage 87.5
    track_files 'lib/**/*.rb'
    add_filter /migrations/
    add_filter /spec/
  end
end

require 'fileutils'
require 'tmpdir'
require 'yaml'
ENV['DATABASE_URL'] ||= 'sqlite3::memory:'
require 'debci/db'
require 'debci/job'

require 'database_cleaner'
DatabaseCleaner.allow_remote_database_url = true
DatabaseCleaner.strategy = :transaction

Debci.config.backend = 'fake'
Debci.config.quiet = true
Debci::DB.migrate

RSpec.shared_context 'tmpdir' do
  let(:arch) { `dpkg --print-architecture`.strip }
  let(:tmpdir) { Dir.mktmpdir }
  after(:each) { FileUtils.rm_rf(tmpdir) }
end

RSpec.configure do |config|
  config.before(:each) do
    allow_any_instance_of(Debci::Job).to receive(:enqueue)
  end
  config.before(:each) do
    allow(Debci).to receive(:warn)
    allow_any_instance_of(Debci::Config).to receive(:arch_list).and_return([`dpkg --print-architecture`.strip])
    allow_any_instance_of(Debci::Config).to receive(:suite_list).and_return(['unstable', 'testing'])
  end
  config.before(:each) do
    DatabaseCleaner.start
  end
  config.after(:each) do
    DatabaseCleaner.clean
  end
end
