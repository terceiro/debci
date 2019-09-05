class IncreaseJobVersion < Debci::DB::LEGACY_MIGRATION
  def up
    change_column :jobs, :version, :string, limit: 256
  end

  def down
    change_column :jobs, :version, :string, limit: 100
  end
end
