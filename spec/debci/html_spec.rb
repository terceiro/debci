require 'json'
require 'pathname'
require 'spec_helper'
require 'debci/html'

describe Debci::HTML do
  include_context 'tmpdir'

  before(:each) do
    allow_any_instance_of(Debci::Config).to receive(:html_dir).and_return(tmpdir + '/html')
    allow_any_instance_of(Debci::Config).to receive(:data_basedir).and_return(tmpdir + '/data')
  end

  let(:html) { Pathname(tmpdir) / 'html' }
  let(:data) { Pathname(tmpdir) / 'data' }

  context 'generating global pages' do
    before(:each) { Debci::HTML.update }
    it('produces home page') { expect(html / 'index.html').to exist }
    it('produces status page') { expect(html / 'status/index.html').to exist }
    it('produces global feed') do
      feed = data / 'feeds' / 'all-packages.xml'
      expect(feed).to exist
      RSS::Parser.parse(feed.open)
    end
  end

  let(:job) do
    Debci::Job.create!(
      package: 'foobar',
      suite: 'unstable',
      arch: 'amd64',
      requestor: 'user',
      status: 'pass',
      date: Time.now,
      duration_seconds: 42,
      version: '1.0-1',
    ).tap do |j|
      (data / ('autopkgtest/unstable/amd64/f/foobar/%<id>d' % { id: j.id })).mkpath
    end
  end

  context 'producing JSON data' do
    before do
      Debci::HTML.update_package(job.package)
      Debci::HTML.update
    end

    it 'produces status.json' do
      status = data / 'status/unstable/amd64/status.json'
      expect(status).to exist
      status = ::JSON.parse(status.read)
      expect(status["pass"]).to eq(1)
      Time.parse(status["date"])
    end

    it 'produces status of the day' do
      today = data / Time.now.strftime('status/unstable/amd64/%Y/%m/%d.json')
      expect(today).to exist
      status = ::JSON.parse(today.read)
      expect(status["pass"]).to eq(1)
    end

    it 'produces history.json' do
      history = data / 'status/unstable/amd64/history.json'
      expect(history).to exist
      history = ::JSON.parse(history.read)
      expect(history.first["pass"]).to eq(1)
    end

    it 'produces packages.json' do
      packages = data / 'status/unstable/amd64/packages.json'
      expect(packages).to exist
      packages = ::JSON.parse(packages.read)
      expect(packages.first["package"]).to eq("foobar")
      expect(packages.first["status"]).to eq("pass")
    end
  end

  context 'package pages' do
    before(:each) do
      Debci::HTML.update_package(job.package)
    end

    let(:pkgdata) { data / 'packages/unstable/amd64/f/foobar' }

    it 'produces package page' do
      expect(html / 'packages/f/foobar/index.html').to exist
    end

    it 'produces package history page for suite/arch' do
      page = html / 'packages/f/foobar/unstable/amd64/index.html'
      expect(page).to exist
      expect(page.read).to include('1.0-1')
    end

    it 'produces history.json' do
      history_json = pkgdata / 'history.json'
      expect(history_json).to exist
      ::JSON.parse(history_json.read)
    end

    it 'produces latest.json' do
      latest_json = pkgdata / 'latest.json'
      expect(latest_json).to exist
      ::JSON.parse(latest_json.read)
    end

    it 'links to latest-autopkgtest' do
      link = pkgdata / 'latest-autopkgtest'
      expect(link).to be_a_symlink
    end

    it 'replaces latest-autopkgtest' do
      # a second time
      Debci::HTML.update_package(job.package)
    end
  end

  context 'producing package news feed' do
    it 'produces feed with news' do
      first = job
      second = Debci::Job.new(first.attributes)
      second.run_id = nil
      second.status = 'fail'
      second.previous_status = first.status
      second.date = Time.now + 1.minute
      second.save!

      Debci::HTML.update_package(job.package)

      feed = data / 'feeds' / job.prefix / "#{job.package}.xml"
      expect(feed).to exist
      feed = RSS::Parser.parse(feed.open)
      expect(feed.items.size).to eq(1)
    end
  end
end