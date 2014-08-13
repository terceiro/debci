require 'rubygems'

require 'debci/repository'

module Debci

  # This class represents different data charts for a specific
  # suite and architecture.
  class Graph

    attr_accessor :date, :pass, :fail, :tmpfail, :total, :pass_percentage

    def initialize
    end

    # Read the status data
    def get_data(suite, architecture)
      data = Debci::Repository.new.status_history(suite, architecture)

      return unless data

      entries = Debci::Graph.new

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
