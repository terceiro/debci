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
end
