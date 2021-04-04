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
      post '/user/foo@bar.com/test/submit', pin_packages: '', trigger: 'test_trigger', package: 'test-package', suite: suite, arch: [arch], export: true
      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to match('application/json')
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

  context 'pagination' do
    it 'links to the last page' do
      pages = Debci::SelfService.get_page_range(1, 30)
      expect(pages).to eq([1, 2, 3, 4, 5, 6, nil, 30])
    end
    it 'links to the first page' do
      pages = Debci::SelfService.get_page_range(30, 30)
      expect(pages).to eq([1, nil, 25, 26, 27, 28, 29, 30])
    end

    it 'links to first and last page' do
      pages = Debci::SelfService.get_page_range(15, 30)
      expect(pages).to eq([1, nil, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, nil, 30])
    end
    it 'links to all pages when there are few of them' do
      pages = Debci::SelfService.get_page_range(1, 5)
      expect(pages).to eq([1, 2, 3, 4, 5])
    end
    it 'links to all pages when on page 6 of 11' do
      pages = Debci::SelfService.get_page_range(6, 11)
      expect(pages).to eq([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11])
    end
  end
end
