require 'bunny'

module Debci
  module AMQP
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
