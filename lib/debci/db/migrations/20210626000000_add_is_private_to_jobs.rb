class AddIsPrivateToJobs < Debci::DB::LEGACY_MIGRATION
  def up
    add_column :jobs, :is_private, :boolean, default: false
  end

  def down
    remove_column :jobs, :is_private
  end
end
