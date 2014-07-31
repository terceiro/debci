require 'rubygems'
require 'gruff'

require 'debci/repository'

module Debci

  # This class represents different data charts for a specific
  # suite and architecture.
  class Graph

    attr_accessor :date, :pass, :fail, :tmpfail, :total, :pass_percentage

    def initialize(graph_size='360x205', y_axis_increment=100)
      @graph_size = graph_size
      @y_axis_increment = y_axis_increment
      @theme = graph_theme(['green', 'red', 'yellow'], 'black')
    end

    # Returns a title for a graph
    def title(suite, architecture)
      "[#{suite}/#{architecture}]"
    end

    # Returns a set of months for the labels of the x-axis
    def month_labels(dates)
      months = dates.map { |date| Time.parse(date).strftime('%B') }
      labels = {}

      months.uniq.each do |month|
        labels.merge!(months.find_index(month) => month[0..2])
      end

      labels
    end

    # Read the status data
    def get_data(suite, architecture)
      data = Debci::Repository.new.status_history(suite, architecture)

      return unless data

      entries = Debci::Graph.new

      entries.date = data.map { |entry| entry['date'] }
      entries.pass = data.map { |entry| entry['pass'] }
      entries.fail = data.map { |entry| entry['fail'] }
      entries.tmpfail = data.map { |entry| entry['tmpfail'] ? entry['tmpfail'] : 0 }
      entries.total = data.map { |entry| entry['total'] }
      entries.pass_percentage = data.map { |entry| entry['pass'].to_f / entry['total'].to_f }

      entries
    end

    private

    def graph_theme(colors, marker_color)
      { :colors => colors, :marker_color => marker_color, :background_colors => 'white' }
    end

  end

end
