require 'yaml'
ENV['DBCONFIG'] = { adapter: :sqlite3, database: ':memory:' }.to_yaml

RSpec.configure do |config|
  config.before(:each) do
    ActiveRecord::Base.connection.tables.reject { |t| t == "schema_migrations" }.each do |table|
      ActiveRecord::Base.connection.execute("DELETE FROM #{table}")
    end
  end
end
