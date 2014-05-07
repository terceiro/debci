module Debci

  class Package < Struct.new(:name, :repository)

    def architectures
      repository.architectures_for(self)
    end

    def suites
      repository.suites_for(self)
    end

  end

end
