require 'json'
require 'time'

module Debci

  # This class represents the test history of a package.

  class History

    # Read the test history for a package on a specific suite and architecture
    def self.get_history(file)
      status = Debci::Status.new
      history = Array.new

      unless File.exists?(file)
        status = "no_test_data"
        return status
      end

      data = nil

      begin
        File.open(file, 'r') do |f|
          data = JSON.load(f)

          # Read the test history data
          status.version = data.map { |test| test['version'] }
          status.run_id = data.map { |test| test['run_id'] }
          status.status = data.map { |test| test['status'] }
          status.date = data.map { |test| Time.parse(test.fetch('date', 'unknown') + ' UTC') }
          status.duration_human = data.map { |test| test['duration_human'] }
          status

          test = 0

          # Store each test
          status.version.each do |this_test|

              test_status = Debci::Status.new

              test_status.version = this_test
              test_status.status = status.status.fetch(test)
              test_status.date = status.date.fetch(test)
              test_status.duration_human = status.duration_human.fetch(test)
              test_status.run_id = status.run_id.fetch(test)

              test += 1

              history.push(test_status)
          end
        end
      rescue JSON::ParserError
        true
      end

      return history
    end
end
end
