require 'active_record'

require 'debci'
require 'debci/package_status'

module Debci
  # This class represents a single package.

  class Package < ::ActiveRecord::Base
    has_many :jobs, class_name: 'Debci::Job'
    has_many :package_status, class_name: 'Debci::PackageStatus'
    validates_format_of :name, with: /\A[a-z0-9][a-z0-9+.-]+\z/

    scope :by_prefix, lambda { |p|
      if p == 'l'
        where("name LIKE :prefix AND name NOT LIKE 'lib%'", prefix: p + '%')
      else
        where("name LIKE :prefix", prefix: p + '%')
      end
    }

    # Returns a matrix of Debci::Job objects, where rows represent
    # architectures and columns represent suites:
    #
    #     [
    #       [ amd64_unstable , amd64_testing ],
    #       [ i386_unstable, i386_testing ],
    #     ]
    #
    # Each cell of the matrix contains a Debci::Job object.
    # Note: Contains statuses which are not blacklisted
    def status
      @status ||=
        begin
          map = package_status.includes(:job).each_with_object({}) do |st, memo|
            memo[st.arch] ||= {}
            memo[st.arch][st.suite] = st.job
          end
          Debci.config.arch_list.map do |arch|
            Debci.config.suite_list.map do |suite|
              map[arch] && map[arch][suite]
            end
          end
        end
    end

    # Returns an array of Debci::Job objects that represent the test
    # history for this package
    def history(suite, architecture)
      jobs.where(suite: suite, arch: architecture)
    end

    def news
      jobs.newsworthy.order('date DESC').first(10)
    end

    # Returns an Array of statuses where this package is failing or neutral.
    def fail_or_neutral
      status.flatten.compact.select { |p| (p.status.to_sym == :fail) || (p.status.to_sym == :neutral) }
    end

    def to_s
      # :nodoc:
      "<Package #{name}>"
    end

    def to_str
      # :nodoc:
      name
    end

    def self.prefixes
      # FIXME: optimize(?)
      select(:name).distinct.pluck(:name).map { |n| prefix(n) }.sort.uniq
    end

    def self.prefix(name)
      name =~ /^((lib)?.)/
      Regexp.last_match(1)
    end

    def prefix
      self.class.prefix(name)
    end

    def blacklisted?(params = {})
      Debci.blacklist.include?(name, params)
    end

    def blacklist_comment(params = {})
      Debci.blacklist.comment(name, params)
    end

    def last_updated_at(suite = nil)
      statuses = status.flatten.compact.select { |s| s.suite == suite || !suite }
      statuses.map(&:date).compact.max
    end
  end
end
