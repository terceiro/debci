require 'json'
require 'time'

module Debci

  # This class represents one test execution.

  class Status

    attr_reader :blame
    attr_accessor :suite, :architecture, :run_id, :package, :version, :date, :status, :previous_status, :duration_seconds, :duration_human, :message, :last_pass_version, :last_pass_date

    # Returns `true` if this status object represents an important event, such
    # as a package that used to pass started failing, of vice versa.
    def newsworthy?
      [
        [:fail, :pass],
        [:pass, :fail],
      ].include?([status, previous_status])
    end

    def title
      {
        :pass => "Pass",
        :fail => "Fail",
        :tmpfail => "Temporary failure",
        :no_test_data => "No test data",
      }.fetch(status, "Unknown")
    end

    # a larger set of possible test result states, to show
    # "at a glance" the package's test history
    # potentially other attributes could be included here
    #  * partial or total failure if there are multiple tests
    #  * dependency failure vs test failure
    #  * guessed nondeterminism
    # but probably too many combinations will make this unhelpful
    def extended_status
      case status
      when :pass
        :pass
      # distinguish between always failing, and whether the test has
      # previously passed for this or older versions
      when :fail
        case last_pass_version
        when "never"
          :fail_passed_never
        when version
          :fail_passed_current
        when "unknown"
          :fail
        else
          :fail_passed_old
        end
      # tmpfail is usually not interesting to the observer, so provide
      # a hint if it is masking a previous pass or fail
      when :tmpfail
        case previous_status
        when :pass
          :tmpfail_pass
        when :fail
          :tmpfail_fail
        else
          :tmpfail
        end
      else
        status
      end
    end

    def failmsg
      {
        :fail_passed_never => "never passed",
        :fail_passed_current => "previously passed",
        :fail_passed_old => "#{last_pass_version} passed"
      }.fetch(extended_status, "unknown")
    end

    # Returns a headline for this status object, to be used as a short
    # description of the event it represents
    def headline
      msg = "#{package} #{version} #{status.upcase}ED on #{suite}/#{architecture}"
      if status == :fail
        msg += " (#{failmsg})"
      end
      msg
    end

    # A longer version of the headline
    # for a new failure, include whether this version previously passed
    def description
      msg = "The tests for #{package}, version #{version}, #{status.upcase}ED on #{suite}/#{architecture} but have previously #{previous_status.upcase}ED"
      msg += case extended_status
        when :fail_passed_current
          " for the current version."
        when :fail_passed_old
          " for version #{last_pass_version}."
        else
          "."
        end
    end

    def blame=(value)
      if value.is_a?(Array)
        @blame = value
      else
        @blame = []
      end
    end

    # Returns the amount of time since the date for this status object
    def time
      days = (Time.now - date)/86400

      if days >= 1 || days <= -1
        "#{days.floor} day(s) ago"
      else
        "#{Time.at(Time.now - date).gmtime.strftime('%H')} hour(s) ago"
      end
    end

    # Constructs a new object by reading the JSON status `file`.
    def self.from_file(file, suite, architecture)
      status = new
      status.suite = suite
      status.architecture = architecture

      unless File.exists?(file)
        status.status = :no_test_data
        return status
      end

      data = nil

      begin
        File.open(file, 'r') do |f|
          data = JSON.load(f)
        end
      rescue JSON::ParserError
        true # nothing really
      end

      return status unless data

      from_data(data, suite, architecture)
    end

    # Populates an object by reading from a data hash
    def self.from_data(data, suite, architecture)
      status = Debci::Status.new

      status.suite = suite
      status.architecture = architecture
      status.run_id = data['run_id'] || data['date']
      status.package = data['package']
      status.version = data['version']
      status.date =
        begin
          Time.parse(data.fetch('date', 'unknown') + ' UTC')
        rescue ArgumentError
          nil
        end
      status.status = data.fetch('status', :unknown).to_sym
      status.previous_status = data.fetch('previous_status', :unknown).to_sym
      status.blame = data['blame']
      status.duration_seconds =
        begin
          Integer(data.fetch('duration_seconds', 0))
        rescue ArgumentError
          nil
        end
      status.duration_human = data['duration_human']
      status.message = data['message']
      status.last_pass_version = data.fetch('last_pass_version', 'unknown')
      status.last_pass_date =
        begin
          Time.parse(data.fetch('last_pass_date', 'unknown') + ' UTC')
        rescue ArgumentError
          nil
        end

      status
    end

    def inspect
      "<#{suite}/#{architecture} #{status}>"
    end

  end

end
