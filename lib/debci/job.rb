require 'debci'
require 'debci/amqp'
require 'debci/db'
require 'debci/test/duration'
require 'debci/test/expired'
require 'debci/test/paths'
require 'debci/test/prefix'
require 'cgi'
require 'time'
require 'pathname'

module Debci
  class Job < ActiveRecord::Base

    include Debci::Test::Duration
    include Debci::Test::Expired
    include Debci::Test::Paths
    include Debci::Test::Prefix

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

    def self.receive(directory)
      src = Pathname(directory)
      id = src.basename.to_s
      Debci::Job.find(id).tap do |job|
        job.status, job.message = status((src / 'exitcode').read.to_i)
        duration = (src / 'duration')
        job.duration_seconds = duration.read.to_i
        job.date = duration.stat.mtime
        job.version = (src / 'testpkg-version').read.split.last

        if job.previous
          job.previous_status = job.previous.status
        end
        if job.last_pass
          job.last_pass_date = job.last_pass.date
          job.last_pass_version = job.last_pass.version
        end

        base = Pathname(Debci.config.autopkgtest_basedir)
        dest = base / job.suite / job.arch / job.prefix / job.package / id
        dest.parent.mkpath
        FileUtils.cp_r src, dest
        Dir.chdir dest do
          artifacts = Dir['*'] - ['log.gz']
          cmd = ['tar', '-caf', 'artifacts.tar.gz', '--remove-files', *artifacts]
          system(*cmd) || raise('Command failed: %<cmd>s' % { cmd: cmd.join(' ') })
        end

        job.save!

        # only remove original directory after everything went well
        src.rmtree
      end
    end

    def self.status(exit_code)
      case exit_code
      when 0
        ['pass', 'All tests passed']
      when 2
        ['pass', 'Tests passed, but at least one test skipped']
      when 4
        ['fail', 'Tests failed']
      when 6
        ['fail', 'Tests failed, and at least one test skipped']
      when 12, 14
        ['fail', 'Erroneous package']
      when 8
        ['neutral', 'No tests in this package or all skipped']
      when 16
        ['tmpfail', 'Could not run tests due to a temporary testbed failure']
      else
        ['tmpfail', "Unexpected autopkgtest exit code #{exit_code}"]
      end
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

    def history
      @history ||= self.class.history(package, suite, arch)
    end

    def past
      @past ||= history.where(["date < ?", date])
    end

    def previous
      @previous ||= past.last
    end

    def last_pass
      @last_pass ||= past.where(status: 'pass').last
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

    def enqueue_parameters
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
      queue = Debci::AMQP.get_queue(arch)
      parameters = enqueue_parameters
      queue.publish("%s %s %s" % [package, suite, parameters.join(' ')], priority: priority)
    end

    def to_s
      "%s %s/%s (%s)" % [package, suite, arch, status || 'pending']
    end

  end
end

