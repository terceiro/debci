require 'spec_helper'
require 'debci/api'
require 'debci/test_handler'
require 'rack/test'
require 'spec_mock_server'

describe Debci::API do
  include Rack::Test::Methods
  include Debci::TestHandler

  include_context 'tmpdir'

  class API < Debci::API
    set :raise_errors, true
    set :show_exceptions, false
  end

  def app
    mock_server('/api', API)
  end

  let(:suite) { Debci.config.suite }
  let(:arch) { Debci.config.arch }

  let(:theuser) do
    Debci::User.create!(username: 'theuser')
  end

  before do
    allow(Debci.config).to receive(:secrets_dir).and_return(tmpdir)
  end

  context 'authentication' do
    it 'does not authenticate with an invalid key' do
      header 'Auth-Key', '1234567890'
      get '/api/v1/auth'
      expect(last_response.status).to eq(403)
    end

    it 'authenticates with a good key' do
      key = Debci::Key.create!(user: theuser).key

      header 'Auth-Key', key
      get '/api/v1/auth'
      expect(last_response.status).to eq(200)
      expect(last_response.headers['Auth-User']).to eq('theuser')
    end
  end

  context 'getting a key' do
    it "can't get a key with invalid auth" do
      keys = Debci::Key.count

      post '/api/v1/getkey'
      expect(last_response.status).to eq(403)

      expect(Debci::Key.count).to eq(keys)
    end

    it 'gets a key based on client certificate' do
      post '/api/v1/getkey', {}, 'SSL_CLIENT_S_DN_CN' => 'foo@bar.com'
      expect(last_response.status).to eq(201)

      user = Debci::User.find_by(username: 'foo@bar.com')
      key = user.keys.first
      expect(key).to_not be_nil
    end

    it 'displays a user-friendly page' do
      get '/api/v1/getkey'
      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to match('text/html')
    end
  end

  context 'receiving test requests' do
    before do
      key = Debci::Key.create!(user: theuser).key

      header 'Auth-Key', key
    end

    context 'for a single test' do
      it 'accepts a valid request' do
        expect_any_instance_of(Debci::Job).to receive(:enqueue)

        post '/api/v1/test/%<suite>s/%<arch>s/mypackage' % { suite: suite, arch: arch }

        job = Debci::Job.last
        expect(job.package.name).to eq('mypackage')
        expect(job.suite).to eq(suite)
        expect(job.arch).to eq(arch)
        expect(job.requestor).to eq('theuser')

        expect(last_response.status).to eq(201)
      end

      it 'enqueues with priority' do
        expect_any_instance_of(Debci::Job).to receive(:enqueue).with(Integer)
        post '/api/v1/test/%<suite>s/%<arch>s/mypackage' % { suite: suite, arch: arch, priority: 8 }
      end

      it 'rejects blacklisted package' do
        allow_any_instance_of(Debci::Blacklist).to receive(:include?)
          .with('mypackage', suite: suite, arch: arch).and_return(true)
        post '/api/v1/test/%<suite>s/%<arch>s/mypackage' % { suite: suite, arch: arch }
        expect(last_response.status).to eq(400)
      end

      it 'rejects invalid package names' do
        jobs = Debci::Job.count
        post '/api/v1/test/%<suite>s/%<arch>s/foo=bar' % { suite: suite, arch: arch }
        expect(last_response.status).to eq(400)
        expect(Debci::Job.count).to eq(jobs)
      end

      it 'rejects unknown arch' do
        post '/api/v1/test/%<suite>s/%<arch>s/mypackage' % { suite: suite, arch: 'xyz' }
        expect(last_response.status).to eq(400)
      end

      it 'rejects unknown suite' do
        post '/api/v1/test/%<suite>s/%<arch>s/mypackage' % { suite: 'nonexistingsuite', arch: arch }
        expect(last_response.status).to eq(400)
      end

      it 'rejects invalid priorities' do
        post '/api/v1/test/%<suite>s/%<arch>s/mypackage' % { suite: 'suite', arch: arch, priority: 0 }
        expect(last_response.status).to eq(400)

        post '/api/v1/test/%<suite>s/%<arch>s/mypackage' % { suite: 'suite', arch: arch, priority: 11 }
        expect(last_response.status).to eq(400)
      end
    end

    context 'for a test batch' do
      it 'accepts a valid request' do
        allow_any_instance_of(Debci::Job).to receive(:enqueue)

        post '/api/v1/test/%<suite>s/%<arch>s' % { suite: suite, arch: arch }, tests: '[{"package": "package1"}, {"package": "package2"}]'

        %w[package1 package2].each do |pkg|
          package = Debci::Package.find_by!(name: pkg)
          job = Debci::Job.where(package: package).last
          expect(job.suite).to eq(suite)
          expect(job.arch).to eq(arch)
          expect(job.requestor).to eq('theuser')
        end

        expect(last_response.status).to eq(201)
      end

      it 'rejects unknown arch' do
        expect_any_instance_of(Debci::Job).to_not receive(:enqueue)
        post '/api/v1/test/%<suite>s/%<arch>s' % { suite: suite, arch: 'xyz' }, tests: '[{"package": "package1"}, {"package": "package2"}]'
        expect(last_response.status).to eq(400)
      end

      it 'rejects unknown suite' do
        expect_any_instance_of(Debci::Job).to_not receive(:enqueue)
        post '/api/v1/test/%<suite>s/%<arch>s' % { suite: 'nonexistingsuite', arch: arch }, tests: '[{"package": "package1"}, {"package": "package2"}]'
        expect(last_response.status).to eq(400)
      end

      it 'marks blacklisted packages as failed right away' do
        allow_any_instance_of(Debci::Blacklist).to receive(:include?).with('package1', suite: suite, arch: arch).and_return(true)
        allow_any_instance_of(Debci::Blacklist).to receive(:include?).with('package2', suite: suite, arch: arch).and_return(false)

        expect_any_instance_of(Debci::Job).to receive(:enqueue).once

        post '/api/v1/test/%<suite>s/%<arch>s' % { suite: suite, arch: arch }, tests: '[{"package": "package1"}, {"package": "package2"}]'
        expect(last_response.status).to eq(201)

        package1 = Debci::Package.find_by!(name: 'package1')
        job1 = Debci::Job.find_by(package: package1, suite: suite, arch: arch)
        expect(job1.status).to eq('fail')
        expect(job1.date).to_not be_nil

        package2 = Debci::Package.find_by!(name: 'package2')
        job2 = Debci::Job.find_by(package: package2, suite: suite, arch: arch)
        expect(job2.status).to be_nil
        expect(job2.date).to be_nil
      end

      it 'rejects invalid package names right away' do
        jobs = Debci::Job.count
        post '/api/v1/test/%<suite>s/%<arch>s' % { suite: suite, arch: arch }, tests: '[{"package": "package1"}, {"package": "foo=package2"}]'
        expect(last_response.status).to eq(400)
        expect(Debci::Job.count).to eq(jobs)
      end

      it 'handles invalid JSON gracefully' do
        expect_any_instance_of(Debci::Job).to_not receive(:enqueue)
        post '/api/v1/test/%<suite>s/%<arch>s' % { suite: suite, arch: arch }, tests: 'invalid json'
        expect(last_response.status).to eq(400)
      end

      test_file = File.join(File.dirname(__FILE__), 'api_test.json')

      it 'handles trigger and pin' do
        expect_any_instance_of(Debci::Job).to receive(:enqueue)

        post '/api/v1/test/%<suite>s/%<arch>s' % { suite: suite, arch: arch }, tests: File.read(test_file)
        expect(last_response.status).to eq(201)

        package1 = Debci::Package.find_by(name: 'package1')
        job = Debci::Job.find_by(suite: suite, arch: arch, package: package1)
        expect(job.trigger).to eq('foo/1.0')
        expect(job.pin_packages).to eq([['src:foo', 'unstable']])
      end

      it 'handles trigger and pin as a file upload' do
        expect_any_instance_of(Debci::Job).to receive(:enqueue)
        post '/api/v1/test/%<suite>s/%<arch>s' % { suite: suite, arch: arch }, tests: Rack::Test::UploadedFile.new(test_file, 'application/json')
        expect(last_response.status).to eq(201)

        package1 = Debci::Package.find_by(name: 'package1')
        job = Debci::Job.find_by(suite: suite, arch: arch, package: package1)
        expect(job.trigger).to eq('foo/1.0')
        expect(job.pin_packages).to eq([['src:foo', 'unstable']])
      end

      batch_test_file = File.join(File.dirname(__FILE__), 'api_test_multi.json')

      it 'saves everything, and only then enqueue' do
        job = Object.new
        expect(Debci::Job).to receive(:create!).with(anything).twice.and_return(job)
        expect(job).to receive(:enqueue).and_raise(Exception)
        expect do
          post '/api/v1/test/%<suite>s/%<arch>s' % { suite: suite, arch: arch }, tests: Rack::Test::UploadedFile.new(batch_test_file, 'application/json')
        end.to raise_error(Exception)
      end
    end
  end

  context 'validating package names' do
    %w[
      foo
      foo-bar
      foo.bar
      foo+
      foo-1.0
      libfoo++
    ].each do |pkg|
      it "accepts #{pkg}" do
        expect(valid_package_name?(pkg)).to be_truthy
      end
    end

    %w[
      foo=bar
      foo~bar
      foo`bar`
      foo$(bar)
      --foo
    ].each do |pkg|
      it "rejects #{pkg}" do
        expect(valid_package_name?(pkg)).to be_falsy
      end
    end
  end

  context 'retriggers' do
    it 'rejects non-authenticated requests' do
      post '/api/v1/retry/1'
      expect(last_response.status).to eq(403)
    end

    it 'displays a user friendly page to authenticated users' do
      get '/api/v1/retry/1', {}, 'SSL_CLIENT_S_DN_CN' => 'foo@bar.com'
      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to match('text/html')
    end

    it 'displays a "Forbidden" page to non-authenticated users' do
      get '/api/v1/retry/1'
      expect(last_response.status).to eq(403)
      expect(last_response.content_type).to match('text/html')
    end

    it 'can retrigger a valid request with key' do
      package = Debci::Package.create!(name: 'mypackage')
      user = 'myuser'
      trigger = 'mypackage/0.0.1'
      pin_packages = ['src:mypackage', 'unstable']
      Debci::Job.create(
        package: package,
        suite: suite,
        arch: arch,
        requestor: user,
        trigger: trigger,
        pin_packages: pin_packages
      )

      job_org = Debci::Job.last

      # Here we are going to retrigger it
      key = Debci::Key.create!(user: theuser).key
      header 'Auth-Key', key
      post "/api/v1/retry/#{job_org.run_id}"

      job = Debci::Job.last
      expect(job.run_id).to eq(job_org.run_id + 1)
      expect(job.package).to eq(package)
      expect(job.suite).to eq(suite)
      expect(job.arch).to eq(arch)
      expect(job.requestor).to eq(user)
      expect(job.trigger).to eq(trigger)
      expect(job.pin_packages).to eq(pin_packages)

      expect(last_response.status).to eq(201)
    end

    it 'can retrigger a valid request with client certificate' do
      package = Debci::Package.create!(name: 'mypackage')
      user = 'myuser'
      trigger = 'mypackage/0.0.1'
      pin_packages = ['src:mypackage', 'unstable']
      Debci::Job.create(
        package: package,
        suite: suite,
        arch: arch,
        requestor: user,
        trigger: trigger,
        pin_packages: pin_packages
      )

      job_org = Debci::Job.last

      # Here we are going to retrigger it
      post "/api/v1/retry/#{job_org.run_id}", {}, 'SSL_CLIENT_S_DN_CN' => 'foo@bar.com'

      expect(last_response.status).to eq(201)

      job = Debci::Job.last
      expect(job.run_id).to eq(job_org.run_id + 1)
    end

    it 'rejects to retrigger an unknown run_id' do
      key = Debci::Key.create!(user: theuser).key
      header 'Auth-Key', key
      post '/api/v1/retry/1'

      expect(last_response.status).to eq(400)
    end
  end
end
