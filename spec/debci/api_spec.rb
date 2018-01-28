require 'debci/api'
require 'rack/test'

describe Debci::API do
  include Rack::Test::Methods

  class API < Debci::API
    set :raise_errors, true
    set :show_exceptions, false
    def __system__(*args)
    end
  end

  App = Rack::Builder.new do
    map '/api' do
      run API
    end
  end

  def app
    App
  end

  let(:suite) { Debci.config.suite }
  let(:arch) { Debci.config.arch }

  before do
    @tmpdir = Dir.mktmpdir
    allow(Debci.config).to receive(:secrets_dir).and_return(@tmpdir)
  end

  after do
    FileUtils.rm_rf(@tmpdir)
  end

  context 'authentication' do
    it 'does not authenticate with an invalid key' do
      header 'Auth-Key', '1234567890'
      get '/api/v1/auth'
      expect(last_response.status).to eq(403)
    end

    it 'authenticates with a good key' do
      km = Debci::API::KeyManager.new
      key = km.set_key('theuser', 'default')

      header 'Auth-Key', key
      get '/api/v1/auth'
      expect(last_response.status).to eq(200)
      expect(last_response.headers['Auth-User']).to eq('theuser')
    end
  end

  context 'receiving test requests' do

    before do
      km = Debci::API::KeyManager.new
      key = km.set_key('theuser', 'default')

      header 'Auth-Key', key
    end

    context 'for a single test' do

      it 'accepts a valid request' do
        expect_any_instance_of(API).to receive(:__system__).with('debci', 'enqueue', '--suite', suite, '--arch', arch, '--requestor', 'theuser', '--run-id', String, 'mypackage')
        post '/api/v1/test/%s/%s/mypackage' % [suite, arch]
        expect(last_response.status).to eq(201)
      end

      it 'rejects blacklisted package' do
        allow_any_instance_of(Debci::Blacklist).to receive(:include?).with('mypackage').and_return(true)
        post '/api/v1/test/%s/%s/mypackage' % [suite, arch]
        expect(last_response.status).to eq(400)
      end

      it 'rejects unknown arch' do
        post '/api/v1/test/%s/%s/mypackage' % [suite, 'xyz']
        expect(last_response.status).to eq(400)
      end

      it 'rejects unknown suite' do
        post '/api/v1/test/%s/%s/mypackage' % ['nonexistingsuite', arch]
        expect(last_response.status).to eq(400)
      end

    end

    context 'for test a batch' do

      it 'accepts a valid request' do
        expect_any_instance_of(API).to receive(:__system__).with('debci', 'enqueue', '--suite', suite, '--arch', arch,  '--requestor', 'theuser', '--run-id', String, 'package1')
        expect_any_instance_of(API).to receive(:__system__).with('debci', 'enqueue', '--suite', suite, '--arch', arch, '--requestor', 'theuser', '--run-id', String, 'package2')
        post '/api/v1/test/%s/%s' % [suite, arch], tests: '[{"package": "package1"}, {"package": "package2"}]'
        expect(last_response.status).to eq(201)
      end

      it 'rejects unknown arch' do
        expect_any_instance_of(API).to_not receive(:__system__)
        post '/api/v1/test/%s/%s' % [suite, 'xyz'], tests: '[{"package": "package1"}, {"package": "package2"}]'
        expect(last_response.status).to eq(400)
      end

      it 'rejects unknown suite' do
        expect_any_instance_of(API).to_not receive(:__system__)
        post '/api/v1/test/%s/%s' % ['nonexistingsuite', arch], tests: '[{"package": "package1"}, {"package": "package2"}]'
        expect(last_response.status).to eq(400)
      end

      it 'rejects blacklisted package' do
        expect_any_instance_of(API).to_not receive(:__system__)
        allow_any_instance_of(Debci::Blacklist).to receive(:include?).with('package1').and_return(true)
        post '/api/v1/test/%s/%s' % [suite, arch], tests: '[{"package": "package1"}, {"package": "package2"}]'
        expect(last_response.status).to eq(400)
      end

      it 'handles invalid JSON gracefully' do
        expect_any_instance_of(API).to_not receive(:__system__)
        post '/api/v1/test/%s/%s' % [suite, arch], tests: 'invalid json'
        expect(last_response.status).to eq(400)
      end

      test_file = File.join(File.dirname(__FILE__), 'api_test.json')

      it 'handles trigger and pin' do
        expect_any_instance_of(API).to receive(:__system__).with(
          'debci', 'enqueue',
          '--suite', suite,
          '--arch', arch,
          '--requestor', 'theuser',
          '--run-id', String,
          '--trigger', 'foo/1.0',
          '--pin-packages', 'unstable=src:foo',
          'package1')
        post '/api/v1/test/%s/%s' % [suite, arch], tests: File.read(test_file)
        expect(last_response.status).to eq(201)
      end

      it 'handles trigger and pin as a file upload' do
        expect_any_instance_of(API).to receive(:__system__).with(
          'debci', 'enqueue',
          '--suite', suite,
          '--arch', arch,
          '--requestor', 'theuser',
          '--run-id', String,
          '--trigger', 'foo/1.0',
          '--pin-packages', 'unstable=src:foo',
          'package1')
        post '/api/v1/test/%s/%s' % [suite, arch], tests: Rack::Test::UploadedFile.new(test_file, "application/json")
        expect(last_response.status).to eq(201)
      end

    end

  end

end
