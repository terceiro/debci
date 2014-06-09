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

    # Returns a list of Debci::Status objects that are newsworthy for this
    # package. The list is sorted with the most recent entries first and the
    # older entries last.
    def news
      repository.news_for(self)
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
