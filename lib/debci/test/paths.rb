require 'pathname'

module Debci
  module Test
    module Paths
      def root
        @root ||= Pathname(Debci.config.data_basedir)
      end

      def autopkgtest_dir
        @autopkgtest_dir ||= root / 'autopkgtest' / suite / arch / prefix / package / run_id.to_s
      end

      def debci_log
        @debci_log ||= root / 'packages' / suite / arch / prefix / package / (run_id.to_s + '.log')
      end

      def result_json
        @result_json ||= root / 'packages' / suite / arch / prefix / package / (run_id.to_s + '.json')
      end

      def cleanup
        autopkgtest_dir.rmtree if autopkgtest_dir.directory?
        debci_log.unlink if debci_log.exist?
        result_json.unlink if result_json.exist?
      end
    end
  end
end