require "spec_helper"
require 'spec_mock_server'
require 'debci'
require 'debci/frontend'
require 'debci/package'
require 'debci/job'
require 'rack/test'

describe Debci::Frontend do
  include Rack::Test::Methods

  class Frontend < Debci::Frontend
    set :raise_errors, true
    set :show_exceptions, false
  end

  def app
    mock_server('/packages', Frontend)
  end

  let(:suite) { Debci.config.suite }
  let(:arch) { Debci.config.arch }

  it 'redirects /packages/ to /' do
    get '/packages/'
    expect(last_response.status).to eq(302)
    expect(URI.parse(last_response.location).path).to eq("/")
  end

  before do
    @rake = Debci::Package.create!(name: "rake")
    @ruby_defaults = Debci::Package.create!(name: "ruby-defaults")
  end

  it 'lists packages by prefix' do
    get "/packages/r/"
    expect(last_response.body).to match(/rake/)
    expect(last_response.body).to match(/ruby-defaults/)
  end

  context 'showing package page' do
    it 'works' do
      get "/packages/r/rake/"
      expect(last_response.body).to match(/<h2>\s*rake/)
    end

    it 'responds with 404 to non-existing package' do
      get "/packages/x/x-missing/"
      expect(last_response.status).to eq(404)
    end

    it 'validates prefix vs package name' do
      get "/packages/f/rake/"
      expect(last_response.status).to eq(404)
    end
  end

  context 'showing package history' do
    it 'works' do
      Debci::Job.create(
        package: @rake,
        suite: suite,
        arch: arch,
        status: "pass",
        created_at: Time.now,
        updated_at: Time.now,
      )

      get "/packages/r/rake/#{suite}/#{arch}/"
      expect(last_response.body).to match(/pass/)
    end

    it 'validates prefix vs package name' do
      get "/packages/f/rake/#{suite}/#{arch}/"
      expect(last_response.status).to eq(404)
    end
  end

  context 'redirecting' do
    %w[/packages/f /packages/f/foobar /packages/f/foobar/unstable/amd64].each do |path|
      it "redirects #{path} to #{path}/" do
        get path
        expect(last_response.status).to eq(302)
        expect(URI.parse(last_response.location).path).to eq("#{path}/")
      end
    end
  end

  context 'caching' do
    it 'caches pages for 5 minutes' do
      get '/packages/r/rake/'
      expect(last_response.headers['Cache-Control']).to match(/max-age=300/)
    end
    it 'caches redirects for 1 year' do
      get '/packages/r/rake'
      expect(last_response.headers['Cache-Control']).to match(/max-age=31556952/)
    end
  end
end
