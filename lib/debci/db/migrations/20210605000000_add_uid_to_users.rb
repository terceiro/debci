class AddUidToUsers < Debci::DB::LEGACY_MIGRATION
  def up
    add_column :users, :uid, :string, unique: true
  end

  def down
    remove_column :users, :uid
  end
end
