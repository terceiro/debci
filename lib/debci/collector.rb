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
      Debci.log "debci collector started"
      channel = Debci::AMQP.amqp_channel
      queue = Debci::AMQP.results_queue
      queue.subscribe(manual_ack: true) do |delivery_info, _properties, payload|
        Dir.mktmpdir do |dir|
          receive_payload(dir, payload)
        end
        channel.acknowledge(delivery_info.delivery_tag, false)
      end
      begin
        loop { sleep 1 }
      rescue Interrupt
        Debci.log "debci collector stopped"
      end
    end

    def receive_payload(dir, payload)
      return if payload.nil? || payload.empty?
      return unless File.directory?(dir)

      Dir.chdir(dir) do
        results = Pathname('results.tar.gz')
        results.open('wb') do |f|
          f.write(payload)
        end
        begin
          Debci.run('tar', 'xaf', results.to_s)
        rescue Debci::CommandFailed
          Debci.warn("W: received invalid tarball data")
        end
        results.unlink
      end

      exitcodes = Pathname(dir).glob('**/exitcode')
      return if exitcodes.empty?

      receive(exitcodes.first.parent)
    end

    def receive(directory)
      job = Debci::Job.receive(directory)
      Debci::HTML.update_package(job.package, job.suite, job.arch)

      data = {
        package: job.package.name,
        suite: job.suite,
        arch: job.arch,
        status: job.status,
        duration_human: job.duration_human,
      }
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
