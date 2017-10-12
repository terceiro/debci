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
    :arch,
    :arch_list,
    :artifacts_url_base,
    :config_dir,
    :data_basedir,
    :data_retention_days,
    :distro_name,
    :html_dir,
    :packages_dir,
    :secrets_dir,
    :sendmail_from,
    :sendmail_to,
    :suite,
    :suite_list,
    :url_base,
  ) do

    # for development usage
    if !ENV['ADTTMP'] && !system('which debci >/dev/null')
      bin = File.dirname(__FILE__) + '/../../bin'
      if File.exists?(bin)
        ENV['PATH'] = [bin,ENV['PATH']].join(':')
      end
    end

    def initialize
      # :nodoc:
      IO.popen(['debci', 'config', *members.map(&:to_s)]) do |data|
        data.each_line.each do |line|
          key, value = line.strip.split('=')
          if key =~ /_list$/
            value = value.split
          end
          self.send("#{key}=", value)
        end
      end
    end

  end

end
