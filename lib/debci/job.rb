require 'debci'
require 'debci/db'
require 'time'

require 'bunny'

module Debci
  class Job < ActiveRecord::Base

    serialize :pin_packages, Array

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

    def enqueue
      parameters = ['run-id:%s' % id]
      if self.trigger
        parameters << "trigger:#{trigger}"
      end
      Array(self.pin_packages).each do |pin|
        pkg, suite = pin
        parameters << "pin-packages:#{suite}=#{pkg}"
      end
      self.queue.publish("%s %s %s" % [package, suite, parameters.join(' ')])
    end

    def queue
      @queue ||=
        begin
          q = ENV['debci_amqp_queue'] || "debci-#{arch}-#{Debci.config.backend}"
          self.class.amqp_channel.queue(q, durable: true)
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

