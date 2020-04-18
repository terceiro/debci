require 'thor'
require 'debci/html'

module Debci
  class HTML
    class CLI < Thor
      desc 'update', "Updates global HTML pages"
      def update
        Debci::HTML.update
      end

      desc 'update-package PACKAGE [SUITE] [ARCHITECTURE]', 'Updates HTML for a given package, optionally only for the given suite and architecture'
      def update_package(pkg, suite = nil, arch = nil)
        Debci::HTML.update_package(pkg, suite, arch)
      end
    end
  end
end
