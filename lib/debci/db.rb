require 'debci'
require 'active_record'

module Debci
  module DB
    def self.config
      @config ||= ENV['DATABASE_URL'] || Debci.config.database_url
    end

    def self.establish_connection
      ActiveRecord::Base.establish_connection(config)
    end

    def self.migrate
      migrations_path = File.join(File.dirname(__FILE__), 'db', 'migrations')
      ActiveRecord::Migration.verbose = !Debci.config.quiet
      if ActiveRecord.version.release >= Gem::Version.new('6.0')
        # ActiveRecord 6+
        ActiveRecord::MigrationContext.new(migrations_path, ActiveRecord::SchemaMigration).migrate
      else
        # ActiveRecord 5.2
        ActiveRecord::MigrationContext.new(migrations_path).migrate
      end
    end
    version_isnewer = ActiveRecord.version.release < Gem::Version.new('5.1.0')
    LEGACY_MIGRATION = if version_isnewer
                         ActiveRecord::Migration
                       else
                         ActiveRecord::Migration[4.2]
                       end
  end
end

Debci::DB.establish_connection
