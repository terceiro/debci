module Debci
  class Blacklist

    def initialize(config_dir)
      @config_dir = config_dir
    end

    def include?(package)
      packages.keys.include?(String(package))
    end

    def packages
      @packages ||=
        begin
          blacklist_file = File.join(@config_dir, 'blacklist')
          if File.exist?(blacklist_file)
            packages = {}
            reason = ''
            File.readlines(blacklist_file).each do |line|
              if line =~ /^\s*$/
                true # skip blank lines
              elsif line =~ /^\s*#/
                reason << line.sub(/^\s*#\s*/, '').gsub(/(https?:\/\/\S*)/, '<a href="\1">\1</a>')
              else
                pkg = line.strip
                packages[pkg] = reason
                reason = ''
              end
            end
            packages
          else
            {}
          end
        end
    end
  end
end
