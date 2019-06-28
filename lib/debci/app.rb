require 'sinatra'

module Debci
  class App < Sinatra::Base
    before do
      @user = ENV['FAKE_CERTIFICATE_USER'] || env['SSL_CLIENT_S_DN_CN']
    end
  end
end
