module Debci
  class Blacklist
    def initialize
      @config_dir = Debci.config.config_dir
      @suite_list = Debci.config.suite_list
      @arch_list = Debci.config.arch_list
    end

    def include_params(params)
      suite = params[:suite] || '*'
      arch = params[:arch] || '*'
      version = params[:version] || '*'
      [suite, arch, version]
    end

    def include?(name, params = {})
      suite, arch, version = include_params(params)

      return false unless data.keys.include?(name)

      # Find a direct match
      return true  if data.dig(name, suite, arch, version)

      # Contract wildcards
      return true if data.dig(name, '*', '*', version)
      return true if data.dig(name, '*', arch, version)
      return true if data.dig(name, suite, '*', version)

      # Expand wildcards
      if suite == '*'
        return @suite_list.all? do |s|
          include?(name, suite: s, arch: arch, version: version)
        end
      end

      if arch == '*'
        return @arch_list.all? do |a|
          include?(name, suite: suite, arch: a, version: version)
        end
      end
      false
    end

    def comment(name, params = {})
      suite, arch, version = include_params(params)
      data.dig(name, suite, arch, version)
    end

    def packages
      # A package is blacklisted only if it is blacklisted for all suites,
      # architectures and versions.
      @packages ||= data.keys.select { |key| include?(key) }
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
