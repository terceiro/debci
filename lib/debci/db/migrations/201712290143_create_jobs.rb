class CreateJobs < ActiveRecord::Migration
  def up
    create_table :jobs do |t|
      t.datetime :created_at
      t.string  :run_id
      t.string  :suite
      t.string  :arch
      t.string  :package
      t.string  :version
      t.string  :trigger
      t.string  :status
      t.string  :requestor
      t.string  :worker
    end
    add_index :jobs, :requestor
    add_index :jobs, :created_at
    add_index :jobs, [:package, :suite, :arch, :run_id], unique: true
  end

  def down
    drop_table :jobs
  end
end

