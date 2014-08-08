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

    # Returns an array containing the suite/architectures this package is
    # failing. If this package is passing on all suite/architectures, nothing
    # is returned.
    def failures
      passing = nil
      failing_status = []

      status.each do |architecture|
        architecture.each do |suite|
          case suite.status
            when :pass
              passing = true
            when :fail
              passing = nil
              failing_status.push(suite.suite + '/' + suite.architecture)
            when :tmpfail
              passing = true
          end
        end
      end

      return failing_status unless passing
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

  end

end
