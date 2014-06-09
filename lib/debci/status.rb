require 'json'
require 'time'

module Debci

  # This class represents one test execution.

  class Status

    attr_reader :blame
    attr_accessor :suite, :architecture, :run_id, :package, :version, :date, :status, :previous_status, :duration_seconds, :duration_human, :message

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

    # Returns a headline for this status object, to be used as a short
    # description of the event it represents
    def headline
      "#{package} tests #{status.upcase}ED on #{suite}/#{architecture}"
    end

    # A longer version of the headline
    def description
      "The tests for #{package} #{status.upcase}ED on #{suite}/#{architecture} but have previosly #{previous_status.upcase}ED."
    end

    def blame=(value)
      if value.is_a?(Array)
        @blame = value
      else
        @blame = []
      end
    end

    # Constructs a new object by reading the JSON status `file`.
    def self.from_file(file)
      status = new
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

      status.run_id = data['run_id']
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

      status
    end

  end

end
