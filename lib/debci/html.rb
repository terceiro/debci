require 'cgi'
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
      @status_nav = load_template(:status_nav)
      expand_template(:status, filename)
    end

    def status_alerts(filename)
      @tmpfail = @repository.tmpfail_packages
      @alert_number = @tmpfail.length
      expand_template(:status_alerts, filename)
    end

    def platform_specific_issues(filename)
      @status_nav = load_template(:status_nav)
      @issues = @repository.platform_specific_issues
      expand_template(:platform_specific_issues, filename)
    end

    def blacklist(filename)
      @status_nav = load_template(:status_nav)
      expand_template(:blacklist, filename)
    end

    def package(package, filename)
      @package = package
      @moretitle = package.name
      expand_template(:package, filename)
    end

    def prefix(prefix, filename)
      @prefix = prefix
      @moretitle = prefix
      expand_template(:packagelist, filename)
    end

    def obsolete_packages_page(filename)
      expand_template(:packages, filename)
    end

    # expand { SUITE } macro in URLs
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
      @moretitle = "#{package.name}/#{suite}/#{architecture}"
      history = package.history(@suite, @architecture)
      @latest = history && history.first
      expand_template(:history, filename)
    end

    private

    def load_template(template)
      read_template(template).result(binding)
    end

    def read_template(name)
      filename = File.join(File.dirname(__FILE__), 'html', name.to_s + '.erb')
      template = ERB.new(File.read(filename))
      template.filename = filename
      template
    end

    def expand_template(template, filename)
      directory = File.dirname(filename)

      abs_filename = File.join(root_directory, filename)
      FileUtils.mkdir_p(File.dirname(abs_filename))

      @root = directory.split('/').map { |_| '..' }.join('/')

      html = load_template(:layout) do
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

    def escape(text)
      text && CGI.escapeHTML(text)
    end

  end

end
