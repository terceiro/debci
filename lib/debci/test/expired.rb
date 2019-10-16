module Debci
  module Test
    module Expired
      def expired?
        days = Debci.config.data_retention_days.to_i
        if days > 0
          retention_window = days * (24 * 60 * 60)
          Time.now > self.date + retention_window
        else
          false
        end
      end
    end
  end
end
