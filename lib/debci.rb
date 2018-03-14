require 'debci/repository'
require 'debci/config'
require 'debci/blacklist'

module Debci

  class << self

    def config
      @config ||= Debci::Config.new
    end

    def blacklist
      @blacklist ||= Debci::Blacklist.new(config.config_dir)
    end

    def config!(data)
      data.each do |k,v|
        ENV["debci_#{k}"] = v
      end
      @config = nil
      @blacklist = nil
    end

    def log(*s)
      puts(*s) unless config.quiet
    end

  end

end
