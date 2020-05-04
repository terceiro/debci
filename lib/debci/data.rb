require 'set'
require 'tempfile'
require 'tmpdir'

require 'thor'

require 'debci'
require 'debci/html'
require 'debci/job'
require 'debci/package'

module Debci

  module Data

    class Export

      attr_reader :tarball
      attr_reader :root
      attr_reader :entries

      def initialize(tarball)
        @tarball = tarball
        @root = Debci.config.data_basedir
        @entries = []
      end

      def add(pkgname)
        pkg = Debci::Package.find_by!(name: pkgname)

        # add data files
        suites = Debci.config.suite_list
        architectures = Debci.config.arch_list
        glob = "{packages,autopkgtest}/{#{suites.join(',')}}/{#{architectures.join(',')}}/#{pkg.prefix}/#{pkg.name}"
        Dir.chdir(root) do
          Dir[glob].each do |d|
            entries << d
          end
        end

        # add database data
        # FIXME make directory unique
        Dir.chdir(root) do
          FileUtils.mkdir_p('export')
          File.open("export/#{pkg.name}.json", 'w') do |f|
            f.write(Debci::Job.where(package: pkg).to_json)
          end
        end
        entries << "export/#{pkg.name}.json"
      end

      def save
        files_from = Tempfile.new
        files_from.puts(entries.sort)
        files_from.close
        target = File.expand_path(tarball)
        Dir.chdir(root) do
          system('tar', 'caf', target, '--files-from=' + files_from.path)
        end
      end
    end


    class Import

      attr_reader :tarball
      attr_reader :root

      def initialize(tarball)
        @root = Debci.config.data_basedir
        @tarball = tarball
      end

      def import!
        pkgs = Set.new

        Dir.mktmpdir do |tmpdir|
          system('tar', 'xaf', tarball, '-C', tmpdir)
          Dir.chdir(tmpdir) do
            mapping = {}
            Dir['export/*.json'].each do |json|
              jobs = JSON.parse(File.read(json))
              jobs.each do |data|
                # load job to database
                orig_run_id = data.delete('run_id')
                job = load_job(data)

                pkgs.add(job.package)

                mapping[orig_run_id] = job.run_id
                puts"# loaded job: #{orig_run_id} -> #{job.run_id}"
                rename_files(job, orig_run_id)
              end
            end

            Dir['packages/*/*/*/*/history.json'].each do |history|
              data = JSON.parse(File.read(history))
              data.each do |entry|
                old_id = entry['run_id'].to_i
                new_id = mapping[old_id]
                if new_id
                  entry['run_id'] = new_id
                end
              end
              File.open(history, 'w') do |f|
                f.write(JSON.pretty_generate(data))
              end
              puts "# rewrite #{history}"
            end
          end
          puts('# copying data files ...')
          cmd = ['rsync', '-apq', '--exclude=/export', tmpdir + '/', root + '/']
          puts cmd.join(' ')
          system(*cmd)
        end
        update_html(pkgs.to_a)
      end

      def load_job(data)
        job = Debci::Job.new
        job.package = Debci::Package.find_or_create_by!(name: data.delete("package"))
        data.each do |attr, value|
          job[attr] = value if job.attributes.key?(attr)
        end
        job.save!
        job
      end

      def update_html(pkgs)
        pkgs.each do |p|
          Debci::HTML.update_package(p)
        end
        Debci::HTML.update unless pkgs.empty?
      end

      private

      def rename_files(job, orig_run_id)
        return if orig_run_id == job.run_id

        # rename files to match database
        to_rename = Dir["autopkgtest/#{job.suite}/#{job.arch}/*/#{job.package.name}/#{orig_run_id}"]
        to_rename += Dir["packages/#{job.suite}/#{job.arch}/*/#{job.package.name}/#{orig_run_id}.*"]
        to_rename.each do |src|
          dest = src.sub("/#{orig_run_id}", "/#{job.run_id}")
          if File.basename(dest) =~ /\.json$/
            # rewrite file with new run_id
            File.open(dest, 'w') do |f|
              f.write(JSON.pretty_generate(job.as_json))
              FileUtils.rm_f(src)
              puts "# rewrite #{src} -> #{dest}"
            end
          else
            puts "mv #{src} #{dest}"
            FileUtils.mv src, dest
          end
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

