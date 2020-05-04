require 'rubygems'

require 'debci'

module Debci
  # This class represents different data charts for a specific
  # suite and architecture.
  class Graph
    attr_accessor :suite, :architecture, :entries

    def initialize(suite, architecture)
      @suite = suite
      @architecture = architecture
      load_data
    end

    private

    def read_status_history
      history = Pathname(Debci.config.data_basedir) / 'status' / suite / architecture / 'history.json'
      ::JSON.parse(history.read)
    end

    def load_data
      # load all the data
      @entries = read_status_history

      return unless @entries
      return if @entries.size <= 100

      # simplify the data: pick 101 points in the history
      original_entries = @entries
      @entries = (0..100).map do |i|
        j = (i * (original_entries.size - 1).to_f / 100).round
        @entries[j]
      end
    end
  end
end
