require 'fileutils'
require 'pathname'
require 'thor'
require 'debci/job'

module Debci
  class Expiration
    def timestamp
      @timestamp ||= (Pathname(Debci.config.data_basedir) / 'expire.stamp').tap do |t|
        unless t.exist?
          oldest = Debci::Job.minimum(:date)
          FileUtils.touch(t, mtime: oldest)
        end
      end
    end

    def run
      expire_date = Time.now - Debci.config.data_retention.days
      start_date = timestamp.stat.mtime

      jobs = Debci::Job.where(['date >= ? AND date <= ?', start_date, expire_date])
      jobs.in_batches.each do |subset|
        subset.each do |job|
          job.cleanup
          Debci.log('Cleaned up files for job %<job_id>s (%<job>s)' % { job_id: job.run_id, job: job })
        end
      end

      FileUtils.touch(timestamp, mtime: expire_date)
    end

    class CLI < Thor
      desc 'start', 'deletes logs and other files related to expired test jobs'
      def start
        ::Debci::Expiration.new.run
      end
      default_task :start
    end
  end
end
