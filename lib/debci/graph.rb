require 'rubygems'

require 'debci/repository'

module Debci

  # This class represents different data charts for a specific
  # suite and architecture.
  class Graph

    attr_accessor :date, :pass, :fail, :tmpfail, :total, :pass_percentage

    def initialize(suite, architecture)
      @suite = suite
      @architecture = architecture
      @data = get_data
    end

    # Returns the value of the last data entry for the specified field
    def current_value(field)
      data = @data.send(field)
      data.last unless data.length == 0
    end

    # Returns the value of the second to last data entry for the
    # specified field
    def previous_value(field)
      data = @data.send(field)
      data[-2] unless data.length < 2
    end

    # Read the status data
    def get_data
      data = Debci::Repository.new.status_history(@suite, @architecture)

      return unless data

      entries = self

      entries.date = data.map { |entry| Time.parse(entry['date'] + ' UTC') }
      entries.pass = data.map { |entry| entry['pass'] }
      entries.fail = data.map { |entry| entry['fail'] }
      entries.tmpfail = data.map { |entry| entry['tmpfail'] ? entry['tmpfail'] : 0 }
      entries.total = data.map { |entry| entry['total'] }
      entries.pass_percentage = data.map { |entry| entry['pass'].to_f / entry['total'].to_f }

      entries
    end

  end

end
