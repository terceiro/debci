require 'debci/package'
require 'debci/status'

module Debci

  class Repository

    def initialize(path)
      @path = path
      @data_dirs = Dir.glob(File.join(path, '*-*'))
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
          status = Debci::Status.from_file(status_file)
          status.suite = suite
          status.architecture = arch
          status
        end
      end
    end

    def history_for(package)
      Dir.glob(File.join(data_dir('*', '*', package), '[0-9]*.json')).sort_by do |f|
        File.basename(f)
      end.map do |f|
        Debci::Status.from_file(f)
      end
    end

    private

    def data_dir(suite, arch, package)
      package_dir = package.sub(/^((lib)?.).*/, '\1/\&')
      File.join(@path, "#{suite}-#{arch}", 'packages', package_dir)
    end

  end

end
