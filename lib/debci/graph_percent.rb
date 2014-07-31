require 'debci/graph'

module Debci

  # This class represents a pass percentage graph for a specific suite and
  # architecture created by reading the status history JSON.
  class GraphPercent < Graph

    def initialize()
      super()
      @y_axis_increment = 0.25
      @hide_dots = true
      @max_value = 1.0
    end

    # Create a pass percentage chart for a specific suite and architecture
    def graph(suite, architecture, directory)
      graph = Gruff::Line.new(@graph_size)

      graph.title = title(suite, architecture)
      graph.y_axis_increment =  @y_axis_increment
      graph.hide_dots = @hide_dots
      graph.theme = @theme

      data = get_data(suite, architecture)

      return unless data

      graph.data('Pass', data.pass_percentage)
      graph.maximum_value = @max_value

      graph.write(File.join(directory, "percent_#{suite}_#{architecture}.png"))
    end

  end

end
