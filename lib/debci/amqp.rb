require 'bunny'

require 'debci'

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

    def self.results_queue
      q = Debci.config.amqp_results_queue
      self.amqp_channel.queue(q, durable: true)
    end

    def self.amqp_channel
      @conn ||= Bunny.new(Debci.config.amqp_server, amqp_options).tap do |conn|
        conn.start
      end
      @channel ||= @conn.create_channel
    end

    def self.amqp_options
      {
        tls:                  Debci.config.amqp_ssl,
        tls_cert:             Debci.config.amqp_cert,
        tls_ca_certificates:  Debci.config.amqp_cacert,
        tls_key:              Debci.config.amqp_key,
        verify_peer:          true,
      }
    end
  end
end
