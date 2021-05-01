class AddBackendToPackages < Debci::DB::LEGACY_MIGRATION
  def up
    add_column :packages, :backend, :string, null: true
  end

  def down
    remove_column :packages, :backend
  end
end
