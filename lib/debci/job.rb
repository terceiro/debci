require 'debci'
require 'debci/db'
require 'debci/test/duration'
require 'debci/test/expired'
require 'cgi'
require 'time'

require 'bunny'

module Debci
  class Job < ActiveRecord::Base

    include Debci::Test::Duration
    include Debci::Test::Expired

    serialize :pin_packages, Array

    class InvalidStatusFile < RuntimeError; end

    def self.import(status_file, suite, arch)
      status = Debci::Status.from_file(status_file, suite, arch)
      status.run_id = status.run_id.to_i
      job = Debci::Job.find(status.run_id)
      if status.package != job.package
        raise InvalidStatusFile.new("Data in %{file} is for package %{pkg}, while database says that job %{id} is for package %{origpkg}" % {
          file: status_file,
          pkg: status.package,
          id: status.run_id,
          origpkg: job.package,
        })
      end
      job.duration_seconds = status.duration_seconds
      job.date = status.date
      job.last_pass_date = status.last_pass_date
      job.last_pass_version = status.last_pass_version
      job.message = status.message
      job.previous_status = status.previous_status
      job.version = status.version
      job.status = status.status
      job.save!
      job
    end

    def self.pending
      jobs = Debci::Job.where(status: nil).order(:created_at)
    end

    def self.history(package, suite, arch)
      Debci::Job.where(
        package: package,
        suite: suite,
        arch: arch
      ).where.not(status: nil).where(pin_packages: nil).order('date')
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

    def as_json(options = nil)
      super(options).update("duration_human" => self.duration_human)
    end

    def get_enqueue_parameters
      parameters = ['run-id:%s' % id]
      if self.trigger
        parameters << "trigger:#{CGI.escape(trigger)}"
      end
      Array(self.pin_packages).each do |pin|
        pkg, suite = pin
        parameters << "pin-packages:#{suite}=#{pkg}"
      end
      parameters
    end

    def enqueue(priority = 0)
      queue = self.class.get_queue(arch)
      parameters = get_enqueue_parameters()
      queue.publish("%s %s %s" % [package, suite, parameters.join(' ')], priority: priority)
    end

    def self.get_queue(arch)
      @queues ||= {}
      @queues[arch] ||=
        begin
          opts = {
            durable: true,
            arguments: {
              'x-max-priority': 10,
            }
          }
          q = ENV['debci_amqp_queue'] || "debci-tests-#{arch}-#{Debci.config.backend}"
          self.amqp_channel.queue(q, opts)
        end
    end

    def self.amqp_channel
      @conn ||= Bunny.new(Debci.config.amqp_server).tap do |conn|
        conn.start
      end
      @channel ||= @conn.create_channel
    end

  end
end

