require 'debci/status'
require 'debci/package'

module Debci

  class Repository

    def initialize(path=nil)
      path ||= Debci.config.data_basedir
      @path = path
      @data_dirs = Dir.glob(File.join(path, '*-*')).reject { |d| d =~ /\.old$/ }
    end

    def architectures
      @architectures ||= @data_dirs.map { |d| File.basename(d).split('-').last }.uniq
    end

    def suites
      @suites ||= @data_dirs.map { |d| File.basename(d).split('-').first }.uniq
    end

    def packages
      @packages ||= @data_dirs.map { |d| Dir.glob(File.join(d, 'packages/*/*')) }.flatten.map { |d| File.basename(d) }.uniq
    end

    class PackageNotFound < Exception; end

    def find_package(package)
      if !packages.include?(package)
        raise PackageNotFound.new(package)
      end

      Debci::Package.new(package, self)
    end

    def search(query)
      # first try exact match
      match = packages.select { |p| p == query }

      # then try regexp match
      if match.empty?
        re = Regexp.new(query)
        match = packages.select { |p| p =~ re }
      end

      match.map { |p| Debci::Package.new(p, self)}
    end

    def status_for(package)
      architectures.map do |arch|
        suites.map do |suite|
          status_file = File.join(data_dir(suite, arch, package), 'latest.json')
          load_status(status_file, suite, arch)
        end
      end
    end

    def news_for(package, n=10)
      suites = '{' + self.suites.join(',') + '}'
      architectures = '{' + self.architectures.join(',') + '}'
      history = Dir.glob(File.join(data_dir(suites, architectures, package), '[0-9]*.json'))

      news = []

      while !history.empty?
        file = history.pop
        suite_arch = File.basename(File.expand_path(File.dirname(file) + '/../../..'))
        suite, architecture = suite_arch.split('-')
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

    private

    def data_dir(suite, arch, package)
      package_dir = package.sub(/^((lib)?.).*/, '\1/\&')
      File.join(@path, "#{suite}-#{arch}", 'packages', package_dir)
    end

    def load_status(status_file, suite, architecture)
      status = Debci::Status.from_file(status_file)
      status.suite = suite
      status.architecture = architecture
      status
    end

  end

end
