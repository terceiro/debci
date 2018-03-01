require 'debci'
require 'active_record'

module Debci
  module DB

    def self.config
      dbdir = Debci.config.data_basedir
      default_db = File.join(dbdir, 'jobs.sqlite3')
      @config ||= ENV['DATABASE_URL'] || 'sqlite3://%s' % default_db
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
Debci::DB.migrate
