require 'spec_helper'
require 'debci/data'

RSpec.shared_context 'export/import' do
  let(:job_data) do
    {
      'run_id': '9999',
      'package': 'rake',
      'suite': 'unstable',
      'arch': 'amd64',
      'version': '12.3.1-1',
      'status': 'pass'
    }
  end

  before(:each) do
    @tmpdir = Dir.mktmpdir
    allow_any_instance_of(Debci::Config).to receive(:data_basedir).and_return(@tmpdir)
  end

  after(:each) do
    FileUtils.rm_rf(@tmpdir)
  end

  let(:output_tarball) { File.join(@tmpdir, 'export.tar') }
  let(:exporter) { Debci::Data::Export.new(output_tarball) }
  let(:exported_files) { `tar taf #{output_tarball}`.split }

  let(:input_tarball) { File.join(@tmpdir, 'import.tar') }
  let(:importer) { Debci::Data::Import.new(input_tarball) }

  def export!
    Dir.chdir(@tmpdir) do
      FileUtils.mkdir_p 'autopkgtest/unstable/amd64/r/rake/9999'
      FileUtils.touch 'autopkgtest/unstable/amd64/r/rake/9999/log.gz'
      FileUtils.touch 'autopkgtest/unstable/amd64/r/rake/9999/exitcode'
      FileUtils.mkdir_p 'packages/unstable/amd64/r/rake'
      FileUtils.touch 'packages/unstable/amd64/r/rake/9999.log'
      File.open('packages/unstable/amd64/r/rake/9999.json', 'w') do |f|
        f.write(JSON.pretty_generate(job_data))
      end
    end
    Debci::Job.create(job_data)

    exporter.add('rake')
    exporter.save
  end

  def cleanup!
    FileUtils.rm_rf(Dir[File.join(@tmpdir, '**/*')].reject { |f| f == output_tarball })
    FileUtils.mv(output_tarball, input_tarball)
    Debci::Job.delete_all
  end
end

describe Debci::Data::Export do
  include_context 'export/import'

  before(:each) do
    export!
  end

  it 'creates a valid output_tarball' do
    mime_type = `file --brief --mime #{output_tarball}`.strip
    expect(mime_type).to eq('application/x-tar; charset=binary')
  end

  it 'exports history data file' do
    expect(exported_files).to include('export/rake.json')
  end
  it 'exports autopkgtest data' do
    expect(exported_files).to include('autopkgtest/unstable/amd64/r/rake/9999/log.gz')
    expect(exported_files).to include('autopkgtest/unstable/amd64/r/rake/9999/exitcode')
  end
  it 'exports package data' do
    system('cp', output_tarball, '/tmp/')
    expect(exported_files).to include('packages/unstable/amd64/r/rake/9999.log')
  end
end

describe Debci::Data::Import do
  include_context 'export/import'

  before(:each) do
    export!
    cleanup!

    allow(importer).to receive(:puts)
    allow(importer).to receive(:update_html)
    importer.import!
  end

  it 'extract files in data directory' do
    repo = Debci::Repository.new
    expect(repo.find_package('rake')).to_not be_nil
  end

  it 'creates job in database' do
    expect(Debci::Job.count).to eq(1)
    job = Debci::Job.first
    job_data.reject { |k, _v| k == :run_id }.each do |k, v|
      expect(job.send(k)).to eq(v)
    end
  end

  it 'renames files to match job run_id in database' do
    job = Debci::Job.first
    pkgdir = File.join(@tmpdir, 'packages/unstable/amd64/r/rake')
    logs = Dir.chdir(pkgdir) { Dir['*.log'] }
    expect(logs).to include(format('%<id>d.log', id: job.run_id))
  end
end
