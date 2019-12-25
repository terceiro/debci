require 'yaml'

if Kernel.const_defined?('SimpleCov')
  SimpleCov.start do
    minimum_coverage 93.5
  end
end

ENV['DATABASE_URL'] ||= 'sqlite3::memory:'
require 'debci/db'
require 'debci/job'

Debci.config.backend = 'fake'
Debci.config.quiet = true
Debci::DB.migrate

RSpec.configure do |config|
  config.before(:each) do
    ActiveRecord::Base.connection.tables.reject { |t| t == "schema_migrations" }.each do |table|
      ActiveRecord::Base.connection.execute("DELETE FROM #{table}")
    end
    allow_any_instance_of(Debci::Job).to receive(:enqueue)
  end
end
