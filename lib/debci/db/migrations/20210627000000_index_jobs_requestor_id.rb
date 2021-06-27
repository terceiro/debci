class IndexJobsRequestorId < Debci::DB::LEGACY_MIGRATION
  def change
    add_index :jobs, :requestor_id
  end
end
