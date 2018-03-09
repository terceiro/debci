require 'debci'
require 'active_record'

module Debci
  module DB

    def self.config
      @config ||= ENV['DATABASE_URL'] || Debci.config.database_url
    end

    def self.establish_connection
      ActiveRecord::Base.establish_connection(self.config)
    end

    def self.migrate
      migrations_path = File.join(File.dirname(__FILE__), 'db', 'migrations')
      ActiveRecord::Migration.verbose = false
      ActiveRecord::Migrator.migrate(migrations_path, nil)
    end
  end
end

Debci::DB.establish_connection
