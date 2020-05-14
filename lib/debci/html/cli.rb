require 'thor'
require 'debci/html'
require 'debci/package'

module Debci
  class HTML
    class CLI < Thor
      desc 'update', "Updates global HTML pages"
      def update
        Debci::HTML.update
      end

      desc 'update-package PACKAGE [SUITE] [ARCHITECTURE]', 'Updates HTML for a given package, optionally only for the given suite and architecture'
      def update_package(pkg, suite = nil, arch = nil)
        package = Debci::Package.where(name: pkg).first
        Debci::HTML.update_package(package, suite, arch)
      end
    end
  end
end
