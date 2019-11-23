class SetJobDate < Debci::DB::LEGACY_MIGRATION
  def change
    execute "UPDATE jobs SET date = created_at WHERE date IS NULL AND status = 'fail'"
  end
end
