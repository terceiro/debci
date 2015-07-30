require 'debci/repository'
require 'debci/config'

module Debci

  class << self

    def config
      @config ||= Debci::Config.new
    end

    def config!(data)
      data.each do |k,v|
        ENV["debci_#{k}"] = v
      end
      @config = nil
    end

  end

end
