class IndexJobsPackageId < Debci::DB::LEGACY_MIGRATION
  def change
    add_index :jobs, :package_id
  end
end
