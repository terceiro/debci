require "spec_helper"
require 'spec_mock_server'
require 'debci'
require 'debci/self_service'
require 'rack/test'
require 'json'

describe Debci::SelfService do
  include Rack::Test::Methods

  class SelfService < Debci::SelfService
    set :raise_errors, true
    set :show_exceptions, false
  end

  def app
    mock_server('/user', SelfService)
  end

  def create_json_file(obj)
    temp_test_file = Tempfile.new
    temp_test_file.write(JSON.dump(obj))
    temp_test_file.rewind
    temp_test_file
  end

  def login(user)
    get '/user/login', {}, 'SSL_CLIENT_S_DN_CN' => user
  end

  let(:suite) { Debci.config.suite }
  let(:arch) { Debci.config.arch }

  let(:theuser) do
    Debci::User.create!(username: 'foo@bar.com')
  end

  context 'authentication' do
    it 'redirects to self service section to authenticated users' do
      login('foo@bar.com')
      get '/user/'
      expect(last_response.status).to eq(302)
      expect(last_response.location).to match(%r{/user/foo@bar.com$})
    end
    it 'displays self service section to authenticated users' do
      login('foo@bar.com')
      get '/user/foo@bar.com'
      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to match('text/html')
    end
    it 'directs to login to unauthenticated users' do
      get '/user'
      expect(last_response.status).to eq(302)
      expect(last_response.location).to match(%r{/user/login$})
    end
    it 'makes current user available even on public page' do
      login('foo@bar.com')
      get '/user/foo@bar.com/jobs'
      expect(last_response.body).to match('Welcome foo@bar.com')
    end
  end

  context 'request test form' do
    before(:each) do
      login('foo@bar.com')
    end

    it 'exports a json file successfully from test form' do
      job_count = Debci::Job.count
      post '/user/foo@bar.com/test/submit', pin_packages: '', trigger: 'test_trigger', package: 'test-package', suite: suite, arch: [arch], export: true
      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to match('application/json')
      expect(Debci::Job.count).to eq(job_count)
    end

    it 'should return error when exporting a json file from incomplete test form' do
      post '/user/foo@bar.com/test/submit', pin_packages: '', trigger: '', package: '', suite: suite, arch: [arch], export: true
      expect(last_response.status).to eq(400)
    end

    it 'submits a task successfully from the form' do
      post '/user/foo@bar.com/test/submit', pin_packages: '', trigger: 'test_trigger', package: 'test-package', suite: suite, arch: [arch]
      expect(last_response.status).to eq(201)
      job = Debci::Job.last
      expect(job.package.name).to eq('test-package')
      expect(job.trigger).to eq('test_trigger')
      expect(job.arch).to eq(arch)
      expect(job.suite).to eq(suite)
      expect(job.pin_packages).to eq([])
    end

    it 'should return error when submitting form with empty package field' do
      job_count = Debci::Job.count
      post '/user/foo@bar.com/test/submit', pin_packages: '', trigger: 'test_trigger', package: '', suite: suite, arch: [arch]
      expect(Debci::Job.count).to eq(job_count)
      expect(last_response.status).to eq(400)
    end

    it 'should return error when submitting form with empty suite field' do
      job_count = Debci::Job.count
      post '/user/foo@bar.com/test/submit', pin_packages: '', trigger: 'test_trigger', package: 'test-package', suite: '', arch: [arch]
      expect(Debci::Job.count).to eq(job_count)
      expect(last_response.status).to eq(400)
    end

    it 'should return error when submitting form with empty arch field' do
      job_count = Debci::Job.count
      post '/user/foo@bar.com/test/submit', pin_packages: '', trigger: '', package: 'test-package', suite: suite, arch: []
      expect(Debci::Job.count).to eq(job_count)
      expect(last_response.status).to eq(400)
    end
  end

  context 'upload json file' do
    before(:each) do
      login('foo@bar.com')
    end

    it 'submits a task successfully on a valid json file upload' do
      test_json = [
        {
          "suite": suite,
          "arch": [arch],
          "tests": [
            {
              "trigger": "testing",
              "package": "autodep8",
              "pin-packages": [["src:bar", "unstable"], ["foo", "src:bar", "stable"]]
            }
          ]
        }
      ]
      test_file = create_json_file(test_json)
      post '/user/foo@bar.com/test/upload', tests: Rack::Test::UploadedFile.new(test_file)
      expect(last_response.status).to eq(201)
      job = Debci::Job.last
      expect(job.package.name).to eq('autodep8')
      expect(job.suite).to eq(suite)
    end

    it 'should return error with no file selected for uplaod' do
      job_count = Debci::Job.count
      post '/user/foo@bar.com/test/upload', {}
      expect(last_response.status).to eq(400)
      expect(Debci::Job.count).to eq(job_count)
    end

    it 'should return error with an invalid suite' do
      test_json = [
        {
          # invalid suite
          "suite": "xyz",
          "arch": ["arm64", arch],
          "tests": [
            {
              "trigger": "testing",
              "package": "autodep8",
              "pin-packages": [["src:bar", "unstable"], ["foo", "src:bar", "stable"]]
            }
          ]
        }
      ]
      test_file = create_json_file(test_json)
      job_count = Debci::Job.count
      post '/user/foo@bar.com/test/upload', tests: Rack::Test::UploadedFile.new(test_file)
      expect(last_response.status).to eq(400)
      expect(Debci::Job.count).to eq(job_count)
    end

    it 'should return error with an invalid arch' do
      test_json = [
        {
          "suite": "unstable",
          # invalid arch
          "arch": ["xyz", arch],
          "tests": [
            {
              "trigger": "testing",
              "package": "autodep8",
              "pin-packages": [["src:bar", "unstable"], ["foo", "src:bar", "stable"]]
            }
          ]
        }
      ]
      test_file = create_json_file(test_json)
      job_count = Debci::Job.count
      post '/user/foo@bar.com/test/upload', tests: Rack::Test::UploadedFile.new(test_file)
      expect(last_response.status).to eq(400)
      expect(Debci::Job.count).to eq(job_count)
    end

    it 'should not crash on missing arch' do
      test_json = [
        {
          "suite": "unstable",
          "tests": [
            {
              "trigger": "testing",
              "package": "autodep8",
              "pin-packages": [["src:bar", "unstable"], ["foo", "src:bar", "stable"]]
            }
          ]
        }
      ]
      test_file = create_json_file(test_json)
      job_count = Debci::Job.count
      post '/user/foo@bar.com/test/upload', tests: Rack::Test::UploadedFile.new(test_file)
      expect(last_response.status).to eq(400)
      expect(Debci::Job.count).to eq(job_count)
    end
  end

  context 'history' do
    before do
      history_jobs = [
        {
          suite: "unstable",
          arch: arch,
          trigger: "mypackage/0.0.1",
          package: "mypackage",
          pin_packages: ["src:mypackage", "unstable"],
          date: '2019-02-03',
          requestor: "foo@bar.com"
        },
        {
          suite: "unstable",
          arch: arch,
          trigger: "testpackage/0.0.1",
          package: "testpackage",
          pin_packages: ["src:testpackage", "unstable"],
          date: '2019-02-05',
          requestor: "foo@bar.com"
        },
        {
          suite: "unstable",
          arch: "#{arch}xx",
          trigger: "testpackage/0.0.2",
          package: "testpackage",
          pin_packages: ["src:testpackage", "unstable"],
          date: '2019-02-04',
          requestor: "foo@bar.com"
        }
      ]

      history_jobs.each do |job|
        package = Debci::Package.find_or_create_by!(name: job.delete(:package))
        Debci::Job.create(job.merge(package: package))
      end
    end

    it 'displays correct results with package filter' do
      get '/user/foo@bar.com/jobs', package: 'testpackage', trigger: ''
      expect(last_response.status).to eq(200)
      expect(last_response.body).to match('testpackage/0.0.1')
      expect(last_response.body).to match('testpackage/0.0.2')
    end

    it 'accepts * as wildcard' do
      get '/user/foo@bar.com/jobs', package: '*package', trigger: ''
      expect(last_response.status).to eq(200)
      expect(last_response.body).to match('mypackage/0.0.1')
      expect(last_response.body).to match('testpackage/0.0.1')
      expect(last_response.body).to match('testpackage/0.0.2')
    end

    it 'displays correct results with trigger and arch filters' do
      get '/user/foo@bar.com/jobs', package: '', trigger: 'mypackage/0.0.1', arch: [arch]
      expect(last_response.status).to eq(200)
      expect(last_response.body).to match('mypackage/0.0.1')
    end

    it 'displays correct results with arch filter' do
      get '/user/foo@bar.com/jobs', package: '', trigger: '', arch: [arch]
      expect(last_response.status).to eq(200)
      expect(last_response.body).to match('mypackage/0.0.1')
      expect(last_response.body).to match('testpackage/0.0.1')
      expect(last_response.body).to_not match('testpackage/0.0.2')
    end

    it 'displays correct results with all filters' do
      get '/user/foo@bar.com/jobs', package: '%package', trigger: 'package/0.0.1', arch: [arch], suite: [suite]
      expect(last_response.status).to eq(200)
      expect(last_response.body).to match('mypackage/0.0.1')
      expect(last_response.body).to match('testpackage/0.0.1')
      expect(last_response.body).to_not match('testpackage/0.0.2')
    end

    it 'sorts by date with newest first' do
      get '/user/foo@bar.com/jobs', {}
      expect(last_response.body).to match(/testpackage.*mypackage/m)
    end
  end
  context 'retriggers' do
    it 'rejects non-authenticated requests' do
      post '/user/foo@bar.com/retry/1'
      expect(last_response.status).to eq(302)
    end

    it 'displays a "Forbidden" page to non-authenticated users' do
      get '/user/foo@bar.com/retry/1'
      expect(last_response.status).to eq(302)
      expect(last_response.content_type).to match('text/html')
    end

    context 'authenticated' do
      before(:each) do
        login('foo@bar.com')
      end

      it 'displays a user friendly page to authenticated users' do
        package = Debci::Package.create!(name: 'mypackage')
        user = 'foo@bar.com'
        trigger = 'mypackage/0.0.1'
        pin_packages = ['src:mypackage', 'unstable']
        job = Debci::Job.create(
          package: package,
          suite: suite,
          arch: arch,
          requestor: user,
          trigger: trigger,
          pin_packages: pin_packages
        )
        get "/user/foo@bar.com/retry/#{job.id}", {}, 'SSL_CLIENT_S_DN_CN' => 'foo@bar.com'
        expect(last_response.status).to eq(200)
        expect(last_response.content_type).to match('text/html')
      end
      it 'can retrigger a valid request with key' do
        package = Debci::Package.create!(name: 'mypackage')
        user = 'foo@bar.com'
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
        post "/user/foo@bar.com/retry/#{job_org.run_id}"

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
        user = 'foo@bar.com'
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
        post "/user/foo@bar.com/retry/#{job_org.run_id}", {}, 'SSL_CLIENT_S_DN_CN' => 'foo@bar.com'

        expect(last_response.status).to eq(201)

        job = Debci::Job.last
        expect(job.run_id).to eq(job_org.run_id + 1)
      end

      it 'rejects to retrigger an unknown run_id' do
        key = Debci::Key.create!(user: theuser).key
        header 'Auth-Key', key
        post '/user/foo@bar.com/retry/1'

        expect(last_response.status).to eq(400)
      end

      it 'rejects to retrigger run_id of a rejectlisted package' do
        key = Debci::Key.create!(user: theuser).key
        header 'Auth-Key', key

        package = Debci::Package.create!(name: 'mypackage')
        user = 'foo@bar.com'
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
        job = Debci::Job.last
        allow_any_instance_of(Debci::RejectList).to receive(:include?).with(package, suite: suite, arch: arch).and_return(true)
        post "/user/foo@bar.com/retry/#{job.run_id}"

        expect(last_response.status).to eq(403)
      end
    end
  end
end
