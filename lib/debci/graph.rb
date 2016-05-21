require 'rubygems'

require 'debci'

module Debci

  # This class represents different data charts for a specific
  # suite and architecture.
  class Graph

    attr_accessor :suite, :architecture, :entries

    def initialize(repository, suite, architecture)
      @repository = repository
      @suite = suite
      @architecture = architecture
      load_data
    end

    private

    def load_data
      # load all the data
      @entries = @repository.status_history(@suite, @architecture)

      return unless @entries
      return if @entries.size <= 100

      # simplify the data: pick 101 points in the history
      original_entries = @entries
      @entries = (0..100).map do |i|
        j = (i * (original_entries.size-1).to_f / 100).round
        @entries[j]
      end
    end

  end

end
