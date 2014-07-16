module Debci

  # This class represents a pass/fail graph for a specific suite and
  # architecture created by reading the status history JSON.
  class GraphPass < Graph

    def initialize()
      super()
    end

    # Create a pass/fail graph for a specific  suite and architecture
    def graph(suite, architecture, directory)
      graph = Gruff::StackedArea.new(@graph_size)

      graph.title = title(suite, architecture)
      graph.y_axis_increment = @y_axis_increment
      graph.theme = @theme

      data = Debci::Repository.new.status_history(suite, architecture)

      return unless data

      graph.data('Pass', data.map { |entry| entry.pass })
      graph.data('Fail', data.map { |entry| entry.fail })
      graph.data('Tmpfail', data.map { |entry| entry.tmpfail})

      graph.write(File.join(directory, "pass_#{suite}_#{architecture}.png"))

    end

  end

end
