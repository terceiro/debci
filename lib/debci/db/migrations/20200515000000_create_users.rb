class CreateUsers < Debci::DB::LEGACY_MIGRATION
  def up
    create_table :users do |t|
      t.string :username, limit: 256, null: false, unique: true
      t.boolean :admin, default: false
    end

    add_column :keys, :user_id, :integer, null: true
    add_foreign_key :keys, :users
    execute <<~SQL
      INSERT INTO users (username)
      SELECT DISTINCT("user") from keys;

      UPDATE keys SET user_id = users.id
      FROM users
      WHERE users.username = keys.user;
    SQL
    change_column_null :keys, :user_id, false
    remove_column :keys, :user
  end

  def down
    add_column :keys, :user, :string, limit: 256, null: true
    execute <<~SQL
      UPDATE keys
      SET "user" = users.username
      FROM users
      WHERE users.id = keys.user_id
    SQL
    remove_foreign_key :keys, :users
    change_column_null :keys, :user, false
    remove_column :keys, :user_id
    drop_table :users
  end
end
