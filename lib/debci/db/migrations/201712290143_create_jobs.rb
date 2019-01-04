class CreateJobs < Debci::DB::LegacyMigration
  def up
    create_table(:jobs, primary_key: 'run_id') do |t|
      t.timestamps(null: false)
      t.string  :suite, :limit => 100
      t.string  :arch, :limit => 100
      t.string  :package, :limit => 100
      t.string  :version, :limit => 100
      t.string  :trigger
      t.string  :status, :limit => 25
      t.string  :requestor, :limit => 256, index: true
      t.text    :pin_packages
      t.string  :worker
    end
    add_index :jobs, :created_at
    add_index :jobs, :updated_at
  end

  def down
    drop_table :jobs
  end
end

