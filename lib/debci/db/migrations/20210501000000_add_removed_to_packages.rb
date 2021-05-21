class AddRemovedToPackages < Debci::DB::LEGACY_MIGRATION
  def up
    add_column :packages, :removed, :boolean, default: false
  end

  def down
    remove_column :packages, :removed
  end
end
