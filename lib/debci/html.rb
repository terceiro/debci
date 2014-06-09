require 'erb'

require 'debci'
require 'fileutils'

module Debci

  class HTML

    attr_reader :root_directory

    def initialize(root_directory)
      @root_directory = root_directory
    end

    def index(filename)
      expand_template(:index, filename)
    end

    def status(filename)
      expand_template(:status, filename)
    end

    def package(package, filename)
      @package = package
      expand_template(:package, filename)
    end

    def prefix(prefix, filename)
      @prefix = prefix
      expand_template(:packagelist, filename)
    end

    def history(package, suite, architecture, filename)
      @package = package
      @suite = suite
      @architecture = architecture
      expand_template(:history, filename)
    end

    private

    def with_layout
      read_template(:layout).result(binding)
    end

    def read_template(name)
      filename = File.join(File.dirname(__FILE__), 'html', name.to_s + '.erb')
      ERB.new(File.read(filename))
    end

    def expand_template(template, filename)
      directory = File.dirname(filename)

      abs_filename = File.join(root_directory, filename)
      FileUtils.mkdir_p(File.dirname(abs_filename))

      @root = directory.split('/').map { |_| '..' }.join('/')

      html = with_layout do
        read_template(template).result(binding)
      end

      File.open(abs_filename, 'w') do |f|
        f.write(html)
      end
    end

  end

end
