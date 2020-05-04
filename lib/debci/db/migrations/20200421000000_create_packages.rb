class CreatePackages < Debci::DB::LEGACY_MIGRATION
  def up
    create_table(:packages) do |t|
      t.string :name, limit: 128, unique: true
    end
    add_index :packages, :name

    add_column :jobs, :package_id, :integer, null: true
    add_foreign_key :jobs, :packages

    execute "INSERT INTO packages(name) SELECT distinct(package) FROM jobs"
    execute "UPDATE jobs SET package_id = (SELECT packages.id FROM packages WHERE jobs.package = packages.name)"
    change_column_null :jobs, :package_id, false
    remove_column :jobs, :package
  end

  def down
    add_column :jobs, :package, :string
    execute "UPDATE jobs SET package = (SELECT packages.name FROM packages WHERE jobs.package_id = packages.id)"
    remove_foreign_key :jobs, :packages
    remove_column :jobs, :package_id
    drop_table :packages
  end
end
