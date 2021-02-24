Encoding.default_external = Encoding::UTF_8

require 'shellwords'

require 'debci/config'
require 'debci/reject_list'

module Debci
  class CommandFailed < RuntimeError
  end

  class << self
    def config
      @config ||= Debci::Config.new
    end

    def reject_list
      @reject_list ||= Debci::RejectList.new
    end

    def config!(data)
      data.each do |k, v|
        ENV["debci_#{k}"] = v
      end
      @config = nil
      @reject_list = nil
    end

    def log(*str)
      return if config.quiet

      puts(*str)
      $stdout.flush
    end

    def warn(*str)
      $stderr.puts(*str)
    end

    def run(*argv)
      system(*argv)
      return if $?.exitstatus == 0

      cmdline = argv.map { |s| Shellwords.shellescape(s) }.join(' ')
      raise Debci::CommandFailed.new(cmdline)
    end
  end
end
