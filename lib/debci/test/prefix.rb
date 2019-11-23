module Debci
  module Test
    module Prefix
      def prefix
        self.package.gsub(/^((lib)?.).*/, '\1')
      end
    end
  end
end
