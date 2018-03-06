require 'debci/db'
require 'time'

module Debci
  class Job < ActiveRecord::Base

    def self.pending
      jobs = Debci::Job.where(status: nil)
    end

    def prefix
      name = self.package
      name =~ /^((lib)?.)/
      $1
    end

    # Returns the amount of time since the date for this status object
    def time
      days = (Time.now - self.created_at)/86400

      if days >= 1 || days <= -1
        "#{days.floor} day(s) ago"
      else
        "#{Time.at(Time.now - self.created_at).gmtime.strftime('%H')} hour(s) ago"
      end
    end

  end
end

