module Debci
  # This class represents a single package. See Debci::Repository for how to
  # obtain one of these.

  Package = Struct.new(:name, :repository) do
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
    # Note: Contains statuses which are not blacklisted
    def status
      repository.status_for(self)
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
    # Note: Contains all statuses
    def all_status
      repository.all_status_for(self)
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
    # Note: Contains blacklisted statuses
    def blacklisted_status
      repository.blacklisted_status_for(self)
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

    # Returns an Array of statuses where this package is failing.
    def failures
      status.flatten.select { |p| p.status == :fail }
    end

    # Returns an Array of statuses where this package is failing or neutral.
    def fail_or_neutral
      status.flatten.select { |p| (p.status == :fail) || (p.status == :neutral) }
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
      Regexp.last_match(1)
    end

    def blacklisted?(params = {})
      Debci.blacklist.include?(name, params)
    end

    def blacklist_comment(params = {})
      Debci.blacklist.comment(name, params)
    end

    def had_success?(suite = nil)
      status.flatten.select { |p| p.suite == suite || !suite }.any? do |s|
        s.had_success?
      end
    end

    def always_failing?(suite = nil)
      !had_success?(suite)
    end

    def last_updated_at(suite = nil)
      statuses = status.flatten.select { |s| s.suite == suite || !suite }
      statuses.map(&:date).compact.max
    end
  end
end
