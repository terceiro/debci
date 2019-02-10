require 'set'
require 'tmpdir'

require 'minitar'
require 'thor'

require 'debci'
require 'debci/job'
require 'debci/package'

module Debci

  module Data

    class Export

      attr_reader :tarball
      attr_reader :root
      attr_reader :repo
      attr_reader :entries

      def initialize(tarball)
        @tarball = tarball
        @root = Debci.config.data_basedir
        @repo = Debci::Repository.new
        @entries = []
      end

      def add(pkgname)
        pkg = @repo.find_package(pkgname)

        # add data files
        suites = pkg.suites
        architectures = pkg.architectures
        glob = "{packages,autopkgtest}/{#{suites.join(',')}}/{#{architectures.join(',')}}/#{pkg.prefix}/#{pkg.name}"
        Dir.chdir(repo.path) do
          Dir[glob].each do |d|
            entries << d
          end
        end

        # add database data
        # FIXME make directory unique
        Dir.chdir(repo.path) do
          FileUtils.mkdir_p('export')
          File.open("export/#{pkg.name}.json", 'w') do |f|
            f.write(Debci::Job.where(package: pkg.name).to_json)
          end
        end
        entries << "export/#{pkg.name}.json"
      end

      def save
        File.open(tarball, 'wb') do |f|
          Dir.chdir(repo.path) do
            Minitar.pack(entries.sort, f)
          end
        end
      end
    end


    class Import

      attr_reader :tarball
      attr_reader :repo

      def initialize(tarball)
        @repo = Debci::Repository.new
        @tarball = tarball
      end

      def import!
        pkgs = Set.new

        Dir.mktmpdir do |tmpdir|
          Minitar.unpack(tarball, tmpdir)
          Dir.chdir(tmpdir) do
            Dir['export/*.json'].each do |json|
              jobs = JSON.parse(File.read(json))
              jobs.each do |data|
                # load job to database
                job = Debci::Job.new
                orig_run_id = data.delete('run_id')
                job.attributes = data
                job.save!

                pkgs.add(job.package)

                puts"# loaded job: #{orig_run_id} -> #{job.run_id}"
                if orig_run_id != job.run_id
                  # rename files to match database
                  to_rename = Dir["autopkgtest/#{job.suite}/#{job.arch}/*/#{job.package}/#{orig_run_id}"]
                  to_rename += Dir["packages/#{job.suite}/#{job.arch}/*/#{job.package}/#{orig_run_id}.*"]
                  to_rename.each do |src|
                    dest = src.sub("/#{orig_run_id}", "/#{job.run_id}")
                    if File.basename(dest) =~ /\.json$/
                      # rewrite run_id
                      File.open(dest, 'w') do |f|
                        f.write(JSON.pretty_generate(data.merge({"run_id" => job.run_id.to_s})))
                        FileUtils.rm_f(src)
                        puts "# rewrite #{src} -> #{dest}"
                      end
                    else
                      FileUtils::Verbose.mv src, dest
                    end
                  end
                end
              end
            end
          end
          puts('# copying data files ...')
          cmd = ['rsync', '-apq', '--exclude=/export', tmpdir + '/', repo.path + '/']
          puts cmd.join(' ')
          system(*cmd)
        end

        if !pkgs.empty?
          puts '# updating HTML pages ...'
          cmd = ['debci-generate-html'] + pkgs.to_a
          puts cmd.join(' ')
          system(*cmd)
        end
      end
    end

    class CLI < Thor
      desc 'export TARBALL PACKAGE [PACKAGE...]', 'Exports data about PACKAGES'
      def export(tarball, *packages)
        exporter = Debci::Data::Export.new(tarball)
        packages.each do |pkg|
          exporter.add(pkg)
        end
        exporter.save
      end

      desc 'import TARBALL', 'Import data from TARBALL'
      def import(tarball)
        importer = Debci::Data::Import.new(tarball)
        importer.import!
      end

    end
  end
end

