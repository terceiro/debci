require 'spec_mock_server'
require 'debci'
require 'debci/self_service'
require 'rack/test'

describe Debci::SelfService do
  include Rack::Test::Methods

  class SelfService < Debci::SelfService
    set :raise_errors, true
    set :show_exceptions, false
  end

  def app
    mock_server('/selfservice', SelfService)
  end

  let(:suite) { Debci.config.suite }
  let(:arch) { Debci.config.arch }

  context 'authentication' do
    it 'displays self service section to authenticated users' do
      get '/selfservice', {}, 'SSL_CLIENT_S_DN_CN' => 'foo@bar.com'
      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to match('text/html')
    end
    it 'directs to 403 to unauthenticated users' do
      get '/selfservice'
      expect(last_response.status).to eq(403)
      expect(last_response.content_type).to match('text/html')
    end
  end

  context 'request test form' do
    it 'exports a json file successfully from test form' do
      post '/selfservice/test/submit', { pin_packages: '', trigger: 'test_trigger', package: 'test-package', suite: suite, arch: [arch], export: true }, 'SSL_CLIENT_S_DN_CN' => 'foo@bar.com'
      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to match('application/json')
    end

    it 'should return error when exporting a json file from incomplete test form' do
      post '/selfservice/test/submit', { pin_packages: '', trigger: '', package: '', suite: suite, arch: [arch], export: true }, 'SSL_CLIENT_S_DN_CN' => 'foo@bar.com'
      expect(last_response.status).to eq(400)
    end

    it 'submits a task succesfully from the form' do
      post '/selfservice/test/submit', { pin_packages: '', trigger: 'test_trigger', package: 'test-package', suite: suite, arch: [arch] }, 'SSL_CLIENT_S_DN_CN' => 'foo@bar.com'
      expect(last_response.status).to eq(201)
      job = Debci::Job.last
      expect(job.package).to eq('test-package')
      expect(job.trigger).to eq('test_trigger')
      expect(job.arch).to eq(arch)
      expect(job.suite).to eq(suite)
      expect(job.pin_packages).to eq([])
    end

    it 'should return error when submitting form with empty package field' do
      job_count = Debci::Job.count
      post '/selfservice/test/submit', { pin_packages: '', trigger: 'test_trigger', package: '', suite: suite, arch: [arch] }, 'SSL_CLIENT_S_DN_CN' => 'foo@bar.com'
      expect(Debci::Job.count).to eq(job_count)
      expect(last_response.status).to eq(400)
    end

    it 'should return error when submitting form with empty suite field' do
      job_count = Debci::Job.count
      post '/selfservice/test/submit', { pin_packages: '', trigger: 'test_trigger', package: 'test-package', suite: '', arch: [arch] }, 'SSL_CLIENT_S_DN_CN' => 'foo@bar.com'
      expect(Debci::Job.count).to eq(job_count)
      expect(last_response.status).to eq(400)
    end

    it 'should return error when submitting form with empty arch field' do
      job_count = Debci::Job.count
      post '/selfservice/test/submit', { pin_packages: '', trigger: '', package: 'test-package', suite: suite, arch: [] }, 'SSL_CLIENT_S_DN_CN' => 'foo@bar.com'
      expect(Debci::Job.count).to eq(job_count)
      expect(last_response.status).to eq(400)
    end
  end
end
