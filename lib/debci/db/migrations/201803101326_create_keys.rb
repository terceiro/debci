class CreateKeys < Debci::DB::LEGACY_MIGRATION
  def up
    create_table(:keys) do |t|
      t.timestamps(null: false)
      t.string :user, limit: 256, null: false
      t.string :encrypted_key, limit: 40, null: false, index: true
    end
  end

  def down
    drop_table :keys
  end
end
