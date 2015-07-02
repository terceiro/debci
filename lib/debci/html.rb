require 'erb'

require 'debci'
require 'fileutils'

module Debci

  class HTML

    attr_reader :root_directory

    def initialize(root_directory=Debci.config.html_dir)
      @root_directory = root_directory
      @repository = Debci::Repository.new
      @package_prefixes = @repository.prefixes

      @head = read_config_file('head.html')
      @footer = read_config_file('footer.html')
    end

    def index(filename)
      expand_template(:index, filename)
    end

    def status(filename)
      expand_template(:status, filename)
    end

    def package(package, filename)
      @package = package
      expand_template(:package, filename)
    end

    def prefix(prefix, filename)
      @prefix = prefix
      expand_template(:packagelist, filename)
    end

    # expand {SUITE} macro in URLs
    def expand_url(url, suite)
      url && url.gsub('{SUITE}', suite)
    end

    def history(package, suite, architecture, filename)
      @package = package
      @suite = suite
      @architecture = architecture
      @packages_dir = 'data/packages'
      @package_dir = File.join(suite, architecture, package.prefix, package.name)
      @autopkgtest_dir = 'data/autopkgtest'
      @site_url = expand_url(Debci.config.url_base, @suite)
      @artifacts_url_base = expand_url(Debci.config.artifacts_url_base, @suite)
      expand_template(:history, filename)
    end

    private

    def with_layout
      read_template(:layout).result(binding)
    end

    def read_template(name)
      filename = File.join(File.dirname(__FILE__), 'html', name.to_s + '.erb')
      ERB.new(File.read(filename))
    end

    def expand_template(template, filename)
      directory = File.dirname(filename)

      abs_filename = File.join(root_directory, filename)
      FileUtils.mkdir_p(File.dirname(abs_filename))

      @root = directory.split('/').map { |_| '..' }.join('/')

      html = with_layout do
        read_template(template).result(binding)
      end

      File.open(abs_filename, 'w') do |f|
        f.write(html)
      end
    end

    def read_config_file(filename)
      file_path = File.join(Debci.config.config_dir, filename)
      if File.exist?(file_path)
        File.read(file_path)
      end
    end

  end

end
