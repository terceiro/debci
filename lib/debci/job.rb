require 'debci'
require 'debci/amqp'
require 'debci/db'
require 'debci/package'
require 'debci/package_status'
require 'debci/test/duration'
require 'debci/test/expired'
require 'debci/test/paths'
require 'cgi'
require 'time'
require 'pathname'

module Debci
  class Job < ActiveRecord::Base

    belongs_to :package, class_name: 'Debci::Package'
    has_many :package_status, class_name: 'Debci::PackageStatus'

    scope :newsworthy, -> { where(['status in (?) AND previous_status in (?) and status != previous_status', ['pass', 'fail', 'neutral'], ['pass', 'fail', 'neutral']]) }

    scope :finished, -> { where('status is NOT NULL') }

    scope :not_pinned, -> { where('pin_packages is NULL') }

    def pinned?
      !pin_packages.empty?
    end

    # FIXME: move to Debci::PackageStatus
    scope :status_on, lambda { |suite, arch|
      joins(:package_status).where(['package_statuses.suite IN (?) AND package_statuses.arch IN (?)', suite, arch])
    }

    # FIXME: move to Debci::PackageStatus
    scope :all_status, lambda {
      status_on(
        Debci.config.suite_list,
        Debci.config.arch_list
      )
    }

    # FIXME: move to Debci::PackageStatus
    scope :tmpfail, -> { all_status.where(status: 'tmpfail') }

    # FIXME: move to Debci::PackageStatus
    scope :fail, -> { all_status.where(status: 'fail') }

    # FIXME: move to Debci::PackageStatus
    scope :visible, lambda {
      last_visible_time = Time.now - Debci.config.status_visible_days.days
      where('date > :time', time: last_visible_time)
    }

    # FIXME: move to Debci::PackageStatus
    scope :slow, lambda {
      all_status.where('duration_seconds > :time', time: 1.hour)
    }

    after_save do |job|
      next unless job.status
      next unless job.date
      next if job.pinned?
      next if job.history.where(['date > ?', date]).exists?

      job.transaction do
        status = Debci::PackageStatus.find_or_initialize_by(
          package: self.package,
          suite: self.suite,
          arch: self.arch,
        )
        status.job = job
        status.save!
      end
    end

    def self.platform_specific_issues
      all_status.includes(:package).group_by(&:package).select do |_, statuses|
        statuses.map(&:status).uniq.size > 1
      end
    end

    include Debci::Test::Duration
    include Debci::Test::Expired
    include Debci::Test::Paths

    serialize :pin_packages, Array

    class InvalidStatusFile < RuntimeError; end

    def self.import(status_file)
      status = JSON.parse(File.read(status_file))
      run_id = status.delete('run_id').to_i
      package = status.delete('package')
      job = Debci::Job.find(run_id)
      if package != job.package.name
        raise InvalidStatusFile.new("Data in %{file} is for package %{pkg}, while database says that job %{id} is for package %{origpkg}" % {
          file: status_file,
          pkg: package,
          id: run_id,
          origpkg: job.package,
        })
      end
      status.each do |k, v|
        job.send("#{k}=", v)
      end

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

        testpkg_version = src / 'testpkg-version'
        if testpkg_version.exist?
          job.version = testpkg_version.read.split.last if testpkg_version
        else
          job.version = 'n/a'
        end

        if job.previous
          job.previous_status = job.previous.status
        end
        if job.last_pass
          job.last_pass_date = job.last_pass.date
          job.last_pass_version = job.last_pass.version
        end

        base = Pathname(Debci.config.autopkgtest_basedir)
        dest = base / job.suite / job.arch / job.package.prefix / job.package.name / id
        dest.parent.mkpath

        # remove destination directory if it exists; this can happen is a
        # previous receiving was interrupted (e.g. if the daemon is restarte)
        dest.rmtree if dest.exist?

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
      Debci::Job.finished.where(
        package: package,
        suite: suite,
        arch: arch
      ).order('date')
    end

    def history
      @history ||= self.class.history(package, suite, arch)
    end

    def previous_unpinned_jobs
      @past ||= history.not_pinned.where(["date < ?", date])
    end

    def previous
      @previous ||= previous_unpinned_jobs.last
    end

    def last_pass
      @last_pass ||= previous_unpinned_jobs.where(status: 'pass').last
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
      super(options).update(
        "duration_human" => self.duration_human,
        "package" => package.name,
      )
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
      queue.publish("%s %s %s" % [package.name, suite, parameters.join(' ')], priority: priority)
    end

    def to_s
      "%s %s/%s (%s)" % [package.name, suite, arch, status || 'pending']
    end

    def title
      '%s %s' % [version, status]
    end

    def headline
      "#{package.name} #{version} #{status.upcase} on #{suite}/#{arch}"
    end

    def always_failing?
      last_pass_version.nil? || last_pass_version == 'n/a'
    end

    def had_success?
      !always_failing?
    end

  end
end

