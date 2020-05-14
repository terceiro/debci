class CreatePackageStatus < Debci::DB::LEGACY_MIGRATION
  def up
    create_table :package_statuses do |t|
      t.integer :package_id
      t.integer :job_id
      t.string :suite, null: false
      t.string :arch, null: false

      t.index [:package_id, :suite, :arch], unique: true
    end
    add_foreign_key :package_statuses, :packages
    add_foreign_key :package_statuses, :jobs, primary_key: :run_id

    ids = exec_query(%[
      SELECT max(run_id) as run_id
      FROM jobs
      WHERE pin_packages is NULL
            AND status is not NULL
      GROUP BY package_id, suite, arch
    ]).map { |item| item['run_id'] }
    return if ids.empty?

    populate_sql = %[
      INSERT INTO package_statuses(package_id, job_id, suite, arch)
      SELECT package_id, run_id, suite, arch
      FROM jobs
      WHERE run_id IN (%s)
    ] % ids.join(',')
    exec_query(populate_sql)
  end

  def down
    drop_table :package_statuses
  end
end
