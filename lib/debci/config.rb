module Debci

  # This class contains provides a Ruby interface to read debci configuration
  # values.
  #
  # Available configuration items:
  #
  # * +data_basedir+: the root directory used by debci to store test run data
  #
  # There is a globally accessible instance of this class accessible from the
  # +config+ method of the Debci module.
  #
  #     >> Debci.config.data_basedir
  #     => "/path/to/debci/data"
  #
  Config = Struct.new(
    :amqp_server,
    :arch,
    :arch_list,
    :artifacts_url_base,
    :backend,
    :config_dir,
    :data_basedir,
    :data_retention_days,
    :database_url,
    :distro_name,
    :html_dir,
    :packages_dir,
    :pending_status_per_page,
    :quiet,
    :secrets_dir,
    :sendmail_from,
    :sendmail_to,
    :suite,
    :suite_list,
    :url_base,
  ) do

    # for development usage
    if !ENV['ADTTMP']
      bin = File.dirname(__FILE__) + '/../../bin'
      if File.exists?(bin)
        ENV['PATH'] = [bin,ENV['PATH']].join(':')
      end
    end

    def self.types
      @types ||= {
        /_list$/ => lambda { |x| x.split}, # Array
        'quiet' => lambda { |x| x == 'true' }, # boolean
      }
    end

    def self.cast_for(key)
      pair = types.find { |k,v| k === key }
      if pair
        pair[1]
      else
        lambda { |x| x == "" ? nil : x }
      end
    end

    def initialize
      # :nodoc:
      IO.popen(['debci', 'config', *members.map(&:to_s)]) do |data|
        data.each_line.each do |line|
          key, value = line.strip.split('=', 2)
          cast = self.class.cast_for(key)
          value = cast.call(value)
          self.send("#{key}=", value)
        end
      end
    end

  end

end
