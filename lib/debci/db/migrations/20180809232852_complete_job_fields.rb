class CompleteJobFields < Debci::DB::LEGACY_MIGRATION

  def up
    add_column :jobs, :date, :datetime
    add_column :jobs, :duration_seconds, :integer
    add_column :jobs, :last_pass_date, :datetime
    add_column :jobs, :last_pass_version, :string
    add_column :jobs, :message, :string
    add_column :jobs, :previous_status, :string
  end

  def down
    remove_column :jobs, :date
    remove_column :jobs, :duration_seconds
    remove_column :jobs, :last_pass_date
    remove_column :jobs, :last_pass_version
    remove_column :jobs, :message
    remove_column :jobs, :previous_status
  end

end
