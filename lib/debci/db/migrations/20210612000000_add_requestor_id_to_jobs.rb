class AddRequestorIdToJobs < Debci::DB::LEGACY_MIGRATION
  def up
    add_column :jobs, :requestor_id, :integer
    add_foreign_key :jobs, :users, column: :requestor_id
    execute "INSERT INTO users (username) SELECT DISTINCT requestor FROM jobs WHERE requestor NOT IN (SELECT username FROM users)"
    execute "UPDATE jobs SET requestor_id = (SELECT users.id FROM users WHERE jobs.requestor = users.username)"
    change_column_null :jobs, :requestor_id, false
    remove_column :jobs, :requestor
  end

  def down
    add_column :jobs, :requestor, :string
    execute "UPDATE jobs SET requestor = (SELECT users.username FROM users WHERE jobs.requestor_id = users.id)"
    remove_foreign_key :jobs, column: :requestor_id
    remove_column :jobs, :requestor_id
  end
end
