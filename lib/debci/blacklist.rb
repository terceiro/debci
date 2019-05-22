module Debci
  class Blacklist
    def initialize(config_dir)
      @config_dir = config_dir
    end

    def include?(package)
      packages.key?(String(package))
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
                old_str = %r{(https?://\S*)}
                new_str = '<a href="\1">\1</a>'
                reason << line.sub(/^\s*#\s*/, '').gsub(old_str, new_str)
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
