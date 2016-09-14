require 'debian'

module Debci

  # This class represents a single package. See Debci::Repository for how to
  # obtain one of these.

  class Package < Struct.new(:name, :repository)

    # Returns the architectures in which this package is available
    def architectures
      repository.architectures_for(self)
    end

    # Returns the suites in which this package is available
    def suites
      repository.suites_for(self)
    end

    # Returns a matrix of Debci::Status objects, where rows represent
    # architectures and columns represent suites:
    #
    #     [
    #       [ amd64_unstable , amd64_testing ],
    #       [ i386_unstable, i386_testing ],
    #     ]
    #
    # Each cell of the matrix contains a Debci::Status object.
    def status
      repository.status_for(self)
    end

    # return the most recent version number tested on any architecture
    def latest_version(suite)
        statuses = status.flatten.select { |s| s.suite == suite }
        versions = statuses.map {|s| s.version}

        versions.sort! do |x,y|
            case
            when x == y
                0
            when Debian::Dpkg::compare_versions(x, "lt", y)
                -1
            else
                1
            end
        end
        versions.last
    end

    # return whether a given status object reflects the most recent version
    # which has been tested
    # TODO: it might be worth marking as obsolete results over, say 90 days
    # old regardless of version (given they should be re-tested ~monthly), in
    # order to catch packages which have subsequently deleted their tests,
    # for example
    def outdated?(status)
        status.version != latest_version(status.suite)
    end

    # Returns an array of Debci::Status objects that represent the test
    # history for this package
    def history(suite, architecture)
      repository.history_for(self, suite, architecture)
    end

    # Returns a list of Debci::Status objects that are newsworthy for this
    # package. The list is sorted with the most recent entries first and the
    # older entries last.
    def news
      repository.news_for(self)
    end

    # Returns an Array of statuses where this package is temporarily failing.
    def failures
      status.flatten.select { |p| p.status == :fail }
    end

    # Returns an Array of statuses where this package is temporarily failing. If
    def tmpfail
      status.flatten.select { |p| p.status == :tmpfail }
    end

    def to_s
      # :nodoc:
      "<Package #{name}>"
    end

    def to_str
      # :nodoc:
      name
    end

    def prefix
      name =~ /^((lib)?.)/
      $1
    end

    def blacklisted?
      Debci.blacklist.include?(self)
    end

  end

end
