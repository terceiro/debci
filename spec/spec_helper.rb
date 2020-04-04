if ENV["COVERAGE"] != "no"
  require 'simplecov'
  SimpleCov.start do
    minimum_coverage 70.5
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

Debci.config.backend = 'fake'
Debci.config.quiet = true
Debci::DB.migrate

RSpec.shared_context 'tmpdir' do
  let(:tmpdir) { Dir.mktmpdir }
  after(:each) { FileUtils.rm_rf(tmpdir) }
end

RSpec.configure do |config|
  config.before(:each) do
    ActiveRecord::Base.connection.tables.reject { |t| t == "schema_migrations" }.each do |table|
      ActiveRecord::Base.connection.execute("DELETE FROM #{table}")
    end
    allow_any_instance_of(Debci::Job).to receive(:enqueue)
  end
end
