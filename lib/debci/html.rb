require 'cgi'
require 'erb'

require 'debci'
require 'debci/job'
require 'fileutils'

module Debci

  class HTML

    include ActiveSupport::NumberHelper
    attr_reader :root_directory

    def initialize(root_directory=Debci.config.html_dir)
      @root_directory = root_directory
      @repository = Debci::Repository.new
      @package_prefixes = @repository.prefixes

      @head = read_config_file('head.html')
      @footer = read_config_file('footer.html')
    end

    def index(filename)
      @news = @repository.global_news
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

    def status_slow(filename)
      @slow = @repository.slow_packages
      expand_template(:status_slow, filename)
    end

    def status_pending_jobs(dirname)
      @status_nav = load_template(:status_nav)
      @status_per_page = Debci.config.pending_status_per_page.to_i
      @pending_jobs = Debci::Job.pending.length

      @suites_jobs = Hash[@repository.suites.map do |x|
        [x, Debci::Job.pending.where(suite: x).count]
      end
      ]
      generate_status_pending(dirname, nil) # For 'All suites'
      @suites_jobs.each_key { |suite| generate_status_pending(dirname, suite) }
    end

    def status_failing(dirname)
      @status_nav = load_template(:status_nav)

      packages = @repository.failing_packages
      @packages_per_page = Debci.config.failing_packages_per_page.to_i

      @filters = { 'had_success': 'Had Success',
                   'always_failing': 'Always Failing' }

      generate_status_failing(dirname, packages, @filters.each_key,
                              @packages_per_page)
      @repository.suites.map do |suite|
        generate_status_failing(dirname, packages, @filters.each_key,
                                @packages_per_page, suite)
      end
    end

    def platform_specific_issues(dirname)
      @status_nav = load_template(:status_nav)

      @filters = {
        "#{dirname}": ["All", -1],
        "#{dirname}/last_thirty_days": ["Last 30 Days", 30],
        "#{dirname}/last_one_eighty_days": ["Last 180 Days", 180],
        "#{dirname}/last_year": ["Last Year", 365]
      }

      @filters.each do |target, filter|
        generate_platform_specific_issues(target, filter)
      end
    end

    def blacklist(filename)
      @status_nav = load_template(:status_nav)
      expand_template(:blacklist, filename)
    end

    def package(package, filename)
      @package = package
      @moretitle = package.name
      @package_links = load_template(:package_links)
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

    def filesize(filename,format)
      if File.exist?(filename)
        format % number_to_human_size(File.size(filename))
      end
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
      @history = package.history(@suite, @architecture)
      @latest = @history && @history.first
      @package_links = load_template(:package_links)
      expand_template(:history, filename)
    end

    private

    def templates
      @templates ||= {}
    end

    def load_template(template)
      read_template(template).result(binding)
    end

    def read_template(name)
      templates[name] ||= begin
        filename = File.join(File.dirname(__FILE__), 'html', name.to_s + '.erb')
        template = ERB.new(File.read(filename))
        template.filename = filename
        template
      end
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

    ICONS = {
      pass: 'thumbs-up',
      neutral: 'minus-circle',
      fail: 'thumbs-down',
      fail_passed_never: ['thumbs-down', 'ban'],
      fail_passed_current: ['thumbs-down', 'bolt'],
      fail_passed_old: ['thumbs-down', 'arrow-down'],
      tmpfail_pass: 'thumbs-up',
      tmpfail_fail: 'thumbs-down',
      tmpfail: 'question-circle',
      no_test_data: 'question',
    }
    def icon(status)
      status ||= :no_test_data
      Array(ICONS[status.to_sym]).map do |i|
        "<i class='#{status} fa fa-#{i}'></i>"
      end.join(' ')
    end

    def generate_platform_specific_issues(target, filter)
      days = filter[1]
      @issues = @repository.platform_specific_issues.select do |_, statuses|
        statuses.any? do |status|
          status.date && status.newer?(days)
        end
      end
      expand_template(:platform_specific_issues, target.to_s + '/' + 'index.html')
    end

    def generate_status_pending(dirname, suite)
      if suite
        @pending = Debci::Job.pending.where(suite: suite)
        base = "#{dirname}/#{suite}"
      else
        @pending = Debci::Job.pending
        base = dirname
      end

      @current_page = "#{base}/all"
      expand_template(:status_pending_jobs, @current_page + '/' \
                      'index.html')
      @current_page = base
      @pending = @pending.last(@status_per_page)
      expand_template(:status_pending_jobs, @current_page + '/' + 'index.html')
    end

    # Sorts packages by last updated date, then names
    def sort_packages_by_date(packages, suite = nil)
      packages.sort do |x, y|
        x_date = x.last_updated_at(suite)
        y_date = y.last_updated_at(suite)
        if x_date && y_date
          y_date <=> x_date
        elsif x_date || y_date
          x_date ? -1 : 1
        else
          x.name <=> y.name
        end
      end
    end

    def generate_status_failing(dirname, packages, filters, packages_per_page,
                                suite = nil)
      base = "#{dirname}#{'/' + suite if suite}"
      @suite = suite

      sorted_packages = sort_packages_by_date(packages, suite)

      @packages = sorted_packages
      filename = base + '/' + 'all' + '/' + 'index.html'
      expand_template(:status_failing, filename)

      @packages = sorted_packages.first(packages_per_page)
      filename = base + '/' + 'index.html'
      expand_template(:status_failing, filename)

      filters.each do |filter|
        filename = base + '/' + filter.to_s + '/' + 'index.html'
        @packages = sorted_packages.select do |p|
          p.send(filter.to_s + '?', suite)
        end
        expand_template(:status_failing, filename)
      end
    end
  end
end
