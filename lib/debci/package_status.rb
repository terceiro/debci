require 'active_record'
require 'debci/db'
require 'debci/job'
require 'debci/package'

module Debci
  class PackageStatus < ActiveRecord::Base
    belongs_to :package, class_name: 'Debci::Package'
    belongs_to :job, class_name: 'Debci::Job'
    validates_uniqueness_of :package_id, scope: [:suite, :arch]
  end
end
