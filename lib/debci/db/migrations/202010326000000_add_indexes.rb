class AddIndexes < Debci::DB::LEGACY_MIGRATION
  def up
    add_index :jobs, :package
    add_index :jobs, :suite
    add_index :jobs, :arch
  end
end
