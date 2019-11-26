module Debci
  module Test
    module Duration
      def duration_human
        return '(n/a)' if duration_seconds.nil?
        s = duration_seconds.to_i
        {
          h: s / 3600,
          m: (s % 3600) / 60,
          s: s % 60,
        }.select { |_, v| v > 0 }.map { |k, v| v.to_s + k.to_s }.join(' ')
      end
    end
  end
end
