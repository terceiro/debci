module Debci

  class Config < Struct.new(:data_basedir)

    def initialize
      IO.popen(['debci', 'config', *members.map(&:to_s)]) do |data|
        data.each_line.each do |line|
          key, value = line.strip.split('=')
          self.send("#{key}=", value)
        end
      end
    end

  end

end
