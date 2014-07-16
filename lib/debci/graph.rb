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

    # Read the status data
    def self.get_data(data)
      entry = Debci::Graph.new

      entry.date = data['date']
      entry.pass = data['pass']
      entry.fail = data['fail']
      entry.tmpfail = data['tmpfail']
      entry.total = data['total']
      entry.pass_percentage = data['pass'].to_f / data['total'].to_f

      entry
    end

    private

    def graph_theme(colors, marker_color)
      { :colors => colors, :marker_color => marker_color, :background_colors => 'white' }
    end

  end

end
