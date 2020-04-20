require 'shellwords'

require 'debci/repository'
require 'debci/config'
require 'debci/blacklist'

module Debci
  class CommandFailed < Exception
  end

  class << self
    def config
      @config ||= Debci::Config.new
    end

    def blacklist
      @blacklist ||= Debci::Blacklist.new
    end

    def config!(data)
      data.each do |k, v|
        ENV["debci_#{k}"] = v
      end
      @config = nil
      @blacklist = nil
    end

    def log(*str)
      puts(*str) unless config.quiet
    end

    def run(*argv)
      system(*argv)
      if $?.exitstatus != 0
        cmdline = argv.map { |s| Shellwords.shellescape(s) }.join(' ')
        raise Debci::CommandFailed, cmdline
      end
    end
  end
end
