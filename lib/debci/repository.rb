require 'set'

require 'debci/status'
require 'debci/package'

module Debci

  # This class implements the backend access to the debci data files. Normally
  # you should access the data through objects of the Debci::Package class,
  # which you can obtain by calling this class' +find_package+ method.
  #
  #     >> repository = Debci::Repository.new
  #     >> package = repository.find_package('mypackage')
  #
  class Repository

    def initialize(path=nil) # :nodoc:
      path ||= Debci.config.data_basedir
      @path = path
      @data_dirs = Dir.glob(File.join(path, 'packages', '*', '*')).reject { |d| d =~ /\.old$/ }
    end

    # Returns an Array of suites known to this debci instance
    def suites
      @suites ||= Dir.glob(File.join(@path, 'packages', '*')).reject { |d| d =~ /\.old$/ }.map { |d| File.basename(d) }.sort
    end

    # Returns an Array of architectures known to this debci instance
    def architectures
      @architectures ||= @data_dirs.map { |d| File.basename(d) }.uniq.sort
    end

    # Returns a Set of packages known to this debci instance
    def packages
      @packages ||= (@data_dirs.map { |d| Dir.glob(File.join(d, '*/*')) }.flatten.map { |d| File.basename(d) } + Debci.blacklist.packages.keys).to_set
    end

    # Returns an Array of package prefixes known to this debci instance
    def prefixes
      @prefixes ||= @data_dirs.map { |d| Dir.glob(File.join(d, '*/')) }.flatten.map { |d| File.basename(d) }.uniq.sort
    end

    # Returns a Set of packages known to this debci instance that are
    # temporarily failing. If no packages are temporarily failing, nothing
    # is returned.
    def tmpfail_packages
      tmpfail_packages = Set.new

      packages.each do |package|
        suites.each do |suite|
          architectures.each do |arch|
            status = load_status(File.join(data_dir(suite, arch, package), "latest.json"), suite, arch)

            if status.status == :tmpfail
              tmpfail_packages << package
            end
          end
        end
      end

      tmpfail_packages.sort.map { |p| Debci::Package.new(p, self) }
    end

    # Returns an Array of suites for which there is data for +package+.
    def suites_for(package)
      package = String(package)
      data_dirs_for(package).map { |d| File.basename(File.dirname(d)) }.uniq
    end

    # Returns an Array of architectures for which there is data for +package+.
    def architectures_for(package)
      package = String(package)
      data_dirs_for(package).map { |d| File.basename(d) }.uniq
    end

    class PackageNotFound < Exception
      # :nodoc:
    end

    # Returns a single package by its names.
    #
    # Raises a Debci::PackageNotFound is there is no package with that +name+.
    def find_package(name)
      if !packages.include?(name)
        raise PackageNotFound.new(name)
      end

      Debci::Package.new(name, self)
    end

    # Iterates over all packages
    #
    # For each package in the repostory, a Debci::Package object will be passed
    # in to the block passed.
    #
    # Example:
    #
    # repository.each_package do |pkg|
    #   puts pkg
    # end
    #
    def each_package
      packages.sort.each do |pkgname|
        pkg = Debci::Package.new(pkgname, self)
        yield pkg
      end
    end

    # Searches packages by name.
    #
    # Returns a sorted Array of Debci::Package objects. On an exact match, it
    # will return an Array with a single element. Otherwise all packages that
    # match the query (which is converted into a regular expression) are
    # returned.
    def search(query)
      # first try exact match
      match = packages.select { |p| p == query }

      # then try regexp match
      if match.empty?
        re = Regexp.new(query)
        match = packages.select { |p| p =~ re }
      end

      match.sort.map { |p| Debci::Package.new(p, self) }
    end

    # Backend implementation for Debci::Package#status
    def status_for(package)
      architectures.map do |arch|
        suites.map do |suite|
          status_file = File.join(data_dir(suite, arch, package), 'latest.json')
          load_status(status_file, suite, arch)
        end
      end
    end

    def platform_specific_issues
      result = {}
      packages.each do |package|
        statuses = status_for(package).flatten
        if statuses.map(&:status).reject { |s| [:no_test_data, :tmpfail].include?(s) }.uniq.size > 1
          result[Debci::Package.new(package, self)] = statuses
        end
      end
      result
    end

    # Backend implementation for Debci::Package#history
    def history_for(package, suite, architecture)
      return unless File.exists?(file = File.join(data_dir(suite, architecture, package), 'history.json'))

      entries = nil

      File.open(file) do |f|
        entries = JSON.load(f)
      end

      entries.map { |test| Debci::Status.from_data(test, suite, architecture) }
    end

    # Backend implementation for Debci::Package#news
    def news_for(package, n=10)
      suites = '{' + self.suites.join(',') + '}'
      architectures = '{' + self.architectures.join(',') + '}'
      history = Dir.glob(File.join(data_dir(suites, architectures, package), '[0-9]*.json')).sort_by { |f| File.basename(f) }

      news = []

      while !history.empty?
        file = history.pop
        dir = File.expand_path(File.dirname(file) + '/../..')
        suite = File.basename(File.dirname(dir))
        architecture = File.basename(dir)
        status = load_status(file, suite, architecture)
        if status.newsworthy?
          news << status
        end
        if news.size >= n
          break
        end
      end

      news
    end

    # Returns the status history for this debci instance
    def status_history(suite, architecture)
      return unless File.exists?(file = File.join(status_dir(suite, architecture), 'history.json'))

      data = nil

      begin
        File.open(file, 'r') do |f|
          data = JSON.load(f)
        end
      rescue JSON::ParserError
        true
      end

      data
    end

    private
    def data_dir(suite, arch, package)
      File.join(@path, 'packages', "#{suite}", "#{arch}", prefix(package), package)
    end

    def status_dir(suite, arch)
      File.join(@path, 'status', "#{suite}", "#{arch}")
    end

    def prefix(package)
      String(package).sub(/^((lib)?.).*/, '\1')
    end

    def load_status(status_file, suite, architecture)
      Debci::Status.from_file(status_file, suite, architecture)
    end

    def data_dirs_for(package)
      @data_dirs.select { |d| File.exist?(File.join(d, prefix(package), package)) }
    end

  end

end
