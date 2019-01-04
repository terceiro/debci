require 'debci'
require 'active_record'

module Debci
  module DB

    LEGACY = ActiveRecord.version.release() < Gem::Version.new('5.2.0')

    def self.config
      @config ||= ENV['DATABASE_URL'] || Debci.config.database_url
    end

    def self.establish_connection
      ActiveRecord::Base.establish_connection(self.config)
    end

    def self.migrate
      migrations_path = File.join(File.dirname(__FILE__), 'db', 'migrations')
      ActiveRecord::Migration.verbose = !Debci.config.quiet
      version = nil
      if LEGACY
        ActiveRecord::Migrator.migrate(migrations_path, nil)
      else
        ActiveRecord::MigrationContext.new(migrations_path).migrate
      end
    end

    if LEGACY
      LegacyMigration = ActiveRecord::Migration
    else
      LegacyMigration = ActiveRecord::Migration[4.2]
    end

  end

end

Debci::DB.establish_connection
