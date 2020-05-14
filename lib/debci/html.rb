require 'cgi'
require 'erb'
require 'json'
require 'pathname'

require 'debci'
require 'debci/feed'
require 'debci/job'
require 'debci/package'
require 'debci/package_status'
require 'debci/graph'
require 'debci/html_helpers'
require 'fileutils'

module Debci

  class HTML

    class << self

      def update
        html = Debci::HTML.new

        Debci.config.suite_list.each do |suite|
          Debci.config.arch_list.each do |arch|
            json = Debci::HTML::JSON.new(suite, arch)
            json.status
            json.history
            json.packages
          end
        end

        html.index('index.html')
        html.packages_page('packages/index.html')
        html.status('status/index.html')
        html.status_alerts('status/alerts/index.html')
        html.status_slow('status/slow/index.html')
        html.status_pending_jobs('status/pending')
        html.status_failing('status/failing')
        html.blacklist
        html.platform_specific_issues('status/platform-specific-issues')
        html.prefixes
      end

      def update_package(package, suite = nil, arch = nil)
        html = new
        pkgjson = Debci::HTML::PackageJSON.new
        autopkgtest = Debci::HTML::Autopkgtest.new
        feed = Debci::HTML::Feed.new

        suites = suite && [suite] || Debci.config.suite_list
        archs = arch && [arch] || Debci.config.arch_list
        suites.each do |s|
          archs.each do |a|
            pkgjson.history(package, s, a)
            pkgjson.latest(package, s, a)
            autopkgtest.link_latest(package, s, a)
            html.history(package, s, a)
          end
        end

        feed.package(package)

        html.package(package)
      end
    end

    class Rooted
      attr_reader :root

      def datadir
        'packages'
      end

      def initialize
        data_basedir = Debci.config.data_basedir
        @root = Pathname(data_basedir) / datadir
      end
    end

    class JSON < Rooted
      attr_accessor :suite
      attr_accessor :arch

      def datadir
        'status'
      end

      def initialize(suite, arch)
        super()
        self.suite = suite
        self.arch = arch
      end

      def status_packages_data
        @status_packages_data ||=
          Debci::PackageStatus.where(suite: suite, arch: arch).includes(:job)
      end

      def status
        data = {
          pass: 0,
          fail: 0,
          neutral: 0,
          tmpfail: 0,
          total: 0,
        }
        status_packages_data.each do |package_status|
          status = package_status.job.status
          data[status.to_sym] += 1
          data[:total] += 1
        end
        data[:date] = Time.now.strftime('%Y-%m-%dT%H:%M:%S')

        output = ::JSON.pretty_generate(data)

        today = root / suite / arch / Time.now.strftime('%Y/%m/%d.json')
        today.parent.mkpath
        today.write(output)

        current = root / suite / arch / 'status.json'
        current.write(output)
      end

      def history
        status_history = (root / suite / arch).glob('[0-9]*/[0-9]*/[0-9]*.json')
        status_history_data = status_history.sort.map { |f| ::JSON.parse(f.read) }

        h = root / suite / arch / 'history.json'
        h.write(::JSON.pretty_generate(status_history_data))
      end

      def packages
        p = root / suite / arch / 'packages.json'
        p.write(::JSON.pretty_generate(status_packages_data.map(&:job).as_json))
      end
    end

    class PackageJSON < Rooted
      def history(package, suite, arch)
        write_json(
          Debci::Job.history(package, suite, arch),
          [suite, arch, package.prefix, package.name, 'history.json']
        )
      end

      def latest(package, suite, arch)
        write_json(
          Debci::Job.history(package, suite, arch).last,
          [suite, arch, package.prefix, package.name, 'latest.json']
        )
      end

      private

      def write_json(data, path)
        file = root
        path.each do |p|
          file /= p
        end
        file.parent.mkpath
        file.open('w') do |f|
          f.write(::JSON.pretty_generate(data.as_json))
        end
      end
    end

    class Autopkgtest < Rooted
      def link_latest(package, suite, arch)
        job = Debci::Job.history(package, suite, arch).last
        return unless job

        link = root / suite / arch / package.prefix / package.name / 'latest-autopkgtest'
        autopkgtest = Pathname('../../../../../autopkgtest')
        target = autopkgtest / suite / arch / package.prefix / package.name / job.id.to_s

        # not atomic, but also not a big deal
        link.unlink if link.symlink?
        link.make_symlink(target)
      end
    end

    class Feed < Rooted
      def datadir
        'feeds'
      end

      def package(pkg)
        news = pkg.news
        write_feed(news, root / pkg.prefix / "#{pkg.name}.xml") do |feed|
          feed.channel.title = "#{pkg.name} CI news feed"
          feed.channel.about = Debci.config.url_base + "/packages/#{pkg.prefix}/#{pkg.name}/"
          feed.channel.description = [
            "News for #{pkg.name}.",
            'Includes only state transitions (pass-fail, and fail-pass).',
            'Full history is available in the package page and in the published data files.',
          ].join(' ')
        end
      end

      private

      def write_feed(news, feedfile)
        feed = Debci::Feed.new(news) do |f|
          yield(f)
        end
        feedfile.parent.mkpath
        feed.write(feedfile)
      end
    end

    include Debci::HTMLHelpers
    attr_reader :root_directory

    def initialize(root_directory=Debci.config.html_dir)
      @root_directory = root_directory
      @package_prefixes = Debci::Package.prefixes

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
      # Packages with atleast one visible tmpfail status
      @tmpfail = Debci::Job.tmpfail.visible
      @alert_number = @tmpfail.length
      expand_template(:status_alerts, filename)
    end

    def status_slow(filename)
      @slow = Debci::Job.slow.sort_by { |j| j.package.name }
      expand_template(:status_slow, filename)
    end

    def status_pending_jobs(dirname)
      @status_nav = load_template(:status_nav)
      @status_per_page = Debci.config.pending_status_per_page.to_i
      @pending_jobs = Debci::Job.pending.count

      @suites_jobs = Hash[Debci.config.suite_list.map do |x|
        [x, Debci::Job.pending.where(suite: x).count]
      end
      ]
      generate_status_pending(dirname, nil) # For 'All suites'
      @suites_jobs.each_key { |suite| generate_status_pending(dirname, suite) }
    end

    def status_failing(dirname)
      @status_nav = load_template(:status_nav)

      jobs = Debci::Job.fail
      @packages_per_page = Debci.config.failing_packages_per_page

      generate_status_failing(dirname, jobs)

      Debci.config.suite_list.each do |suite|
        generate_status_failing(dirname, jobs, suite)
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

      issues = Debci::Job.platform_specific_issues
      @filters.each do |target, filter|
        generate_platform_specific_issues(issues, target, filter)
      end
    end

    def blacklist
      @status_nav = load_template(:status_nav)
      @blacklist = Debci.blacklist
      expand_template(:blacklist, 'status/blacklist/index.html')
    end

    def package(package)
      @package = package
      @moretitle = package.name
      @package_links = load_template(:package_links)

      filename = "packages/#{package.prefix}/#{package.name}/index.html"
      expand_template(:package, filename)
    end

    def prefixes
      Debci::Package.order('name').group_by(&:prefix).each do |prefix, packages|
        @prefix = prefix
        @moretitle = prefix
        @packages = packages
        @packages.sort_by!(&:name)
        filename = "packages/#{prefix}/index.html"
        expand_template(:packagelist, filename)
      end
    end

    def packages_page(filename)
      expand_template(:packages, filename)
    end

    # expand { SUITE } macro in URLs
    def expand_url(url, suite)
      url && url.gsub('{SUITE}', suite)
    end

    def history(package, suite, architecture)
      @package = package
      @suite = suite
      @architecture = architecture
      @packages_dir = 'data/packages'
      @package_dir = File.join(suite, architecture, package.prefix, package.name)
      @site_url = expand_url(Debci.config.url_base, @suite)
      @artifacts_url_base = expand_url(Debci.config.artifacts_url_base, @suite)
      @moretitle = "#{package.name}/#{suite}/#{architecture}"
      @history = package.history(@suite, @architecture)
      @package_links = load_template(:package_links)

      filename = "packages/#{package.prefix}/#{package.name}/#{suite}/#{architecture}/index.html"
      expand_template(:history, filename)
    end

    private

    def history_url(job)
      "/packages/#{job.package.prefix}/#{job.package.name}/#{job.suite}/#{job.arch}/"
    end

    def package_url(package)
      "/packages/#{package.prefix}/#{package.name}/"
    end

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

    def generate_platform_specific_issues(issues, target, filter)
      @issues = issues

      n = filter[1]
      if n > 0
        cutoff = Time.now - n.days
        @issues = @issues.select do |_, statuses|
          statuses.any? do |status|
            status.date && status.date > cutoff
          end
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

    def generate_status_failing(dirname, jobs, suite = nil)
      base = "#{dirname}#{'/' + suite if suite}"
      @suite = suite

      jobs = jobs.where(suite: suite) if suite
      jobs = jobs.order('date DESC')

      generate_status_failing_index(jobs, base)
      generate_status_failing_all(jobs, base)
      generate_status_failing_always_failing(jobs, base)
      generate_status_failing_had_success(jobs, base)
    end

    def status_failing_title(title)
      @suite && [title, "on", @suite].join(' ') || title
    end

    def generate_status_failing_all(jobs, base)
      @title = 'All failures'
      @jobs = jobs

      filename = "#{base}/all/index.html"
      expand_template(:status_failing, filename)
    end

    def generate_status_failing_index(jobs, base)
      @title = status_failing_title(
        'Last %<packages_per_page>d failures' % { packages_per_page: @packages_per_page }
      )
      @jobs = jobs.first(@packages_per_page)

      filename = "#{base}/index.html"
      expand_template(:status_failing, filename)
    end

    def generate_status_failing_always_failing(jobs, base)
      @title = status_failing_title('Always failing')
      @jobs = jobs.select { |j| j.always_failing? }

      filename = "#{base}/always_failing/index.html"
      expand_template(:status_failing, filename)
    end

    def generate_status_failing_had_success(jobs, base)
      @title = status_failing_title('Had success')
      @jobs = jobs.select { |j| j.had_success? }

      filename = "#{base}/had_success/index.html"
      expand_template(:status_failing, filename)
    end
  end
end
