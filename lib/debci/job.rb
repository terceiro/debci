require 'debci/db'
require 'time'

module Debci
  class Job < ActiveRecord::Base

    def save(**args)
      self.created_at ||= Time.now
      super(**args)
    end
  end
end

