require 'pathname'
require 'thor'
require 'tmpdir'
require 'debci'
require 'debci/amqp'
require 'debci/html'
require 'debci/job'

module Debci
  class Collector
    def run
      channel = Debci::AMQP.amqp_channel
      queue = Debci::AMQP.results_queue
      queue.subscribe(manual_ack: true) do |delivery_info, _properties, payload|
        Dir.mktmpdir do |dir|
          Dir.chdir(dir) do
            results = Pathname('results.tar.gz')
            results.open('wb') do |f|
              f.write(payload)
            end
            system("tar xaf #{results}")
            results.unlink
          end

          results_dir = Pathname(dir).glob('**/exitcode').first.parent
          receive(results_dir)
          channel.acknowledge(delivery_info.delivery_tag, false)
        end
      end
      begin
        loop { sleep 1 }
      rescue Interrupt
        puts
        puts "debci collector stopped"
      end
    end

    def receive(directory)
      job = Debci::Job.receive(directory)
      Debci::HTML.update_package(job.package)

      data = job.attributes.symbolize_keys
      data[:duration_human] = job.duration_human
      Debci.log('%<package>s %<suite>s/%<arch>s %<status>s %<duration_human>s' % data)
    end

    class CLI < Thor
      desc 'run', 'Runs the debci results collector'
      def start
        Collector.new.run
      end
      default_task :start
    end
  end
end
