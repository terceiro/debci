require 'rubygems'

require 'debci'

module Debci

  # This class represents different data charts for a specific
  # suite and architecture.
  class Graph

    attr_accessor :date, :pass, :fail, :tmpfail, :total, :pass_percentage

    def initialize(repository, suite, architecture)
      @repository = repository
      @suite = suite
      @architecture = architecture
      load_data
    end

    # Returns the value of the last data entry for the specified field
    def current_value(field)
      data = send(field)
      data[-1] || 0
    end

    # Returns the value of the second to last data entry for the
    # specified field
    def previous_value(field)
      data = send(field)
      data[-2] || 0
    end

    # Read the status data
    def load_data
      data = @repository.status_history(@suite, @architecture)

      return unless data

      self.date = data.map { |entry| Time.parse(entry['date'] + ' UTC') }
      self.pass = data.map { |entry| entry['pass'] }
      self.fail = data.map { |entry| entry['fail'] }
      self.tmpfail = data.map { |entry| entry['tmpfail'] ? entry['tmpfail'] : 0 }
      self.total = data.map { |entry| entry['total'] }
      self.pass_percentage = data.map { |entry| entry['pass'].to_f / entry['total'].to_f }
    end

  end

end
