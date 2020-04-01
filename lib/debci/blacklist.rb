module Debci
  class Blacklist
    def initialize
      @config_dir = Debci.config.config_dir
      @suite_list = Debci.config.suite_list
      @arch_list = Debci.config.arch_list
    end

    def unpack_params(params)
      suite = params[:suite] || '*'
      arch = params[:arch] || '*'
      version = params[:version] || '*'
      [suite, arch, version]
    end

    def include?(name, params = {})
      name = String(name)
      suite, arch, version = unpack_params(params)

      return find_expanding_package_name(name, params) unless data.key?(name)

      if data[name].key?(suite)
        nil
      elsif data[name].key?('*')
        suite = '*'
      else
        return find_expanding_wildcards(name, params)
      end

      if data[name][suite].key?(arch)
        nil
      elsif data[name][suite].key?('*')
        arch = '*'
      else
        return find_expanding_wildcards(name, params)
      end

      return true if [version, '*'].include?(data[name][suite][arch].keys.first)

      find_expanding_wildcards(name, params)
    end

    def find_expanding_package_name(name, params)
      suite, arch, version = unpack_params(params)
      # Expand package name
      data.keys.select { |k| File.fnmatch(k, name) }.each do |wildcard|
        return true if include?(wildcard, suite: suite, arch: arch, version: version)
      end
      # None of the package name wildcards match
      false
    end

    def find_expanding_wildcards(name, params)
      suite, arch, version = unpack_params(params)

      if suite == '*'
        return @suite_list.all? do |s|
          include?(name, suite: s, arch: arch, version: version)
        end
      end

      return unless arch == '*'

      @arch_list.all? do |a|
        include?(name, suite: suite, arch: a, version: version)
      end
    end

    def comment(name, params = {})
      suite, arch, version = unpack_params(params)
      data.dig(name, suite, arch, version)
    end

    def packages
      # A package is blacklisted only if it is blacklisted for all suites,
      # architectures and versions.
      @packages ||= data.keys.select { |key| !key.include?("*") && include?(key) }
    end

    def data
      @data ||=
        begin
          blacklist_file = File.join(@config_dir, 'blacklist')
          if File.exist?(blacklist_file)
            data = {}
            reason = ''
            File.readlines(blacklist_file).each do |line|
              if line =~ /^\s*$/
                true # skip blank lines
              elsif line =~ /^\s*#/
                old_str = %r{(https?://\S*)}
                new_str = '<a href="\1">\1</a>'
                reason << line.sub(/^\s*#\s*/, '').gsub(old_str, new_str)
              else
                pkg, suite, arch, version = line.strip.split

                suite ||= '*'
                arch ||= '*'
                version ||= '*'

                data[pkg] ||= {}
                data[pkg][suite] ||= {}
                data[pkg][suite][arch] ||= {}
                data[pkg][suite][arch][version] = reason
                reason = ''
              end
            end
            data
          else
            {}
          end
        end
    end
  end
end
