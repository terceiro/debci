require 'debci/repository'
require 'debci/config'

module Debci

  class << self

    def config
      @config ||= Debci::Config.new
    end

  end

end
