require 'sinatra'
require 'json'

require 'debci/app'
require 'debci/test_handler'

module Debci
  class SelfService < Debci::App
    include Debci::TestHandler
    set :views, File.dirname(__FILE__) + '/html'

    configure do
      set :suites, Debci.config.suite_list
      set :archs, Debci.config.arch_list
    end

    before '/*' do
      halt(403, "Unauthenticated!\n") unless @user
    end

    get '/' do
      erb :self_service
    end
  end
end
