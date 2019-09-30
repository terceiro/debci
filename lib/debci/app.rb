require 'sinatra'
require 'erb'

module Debci
  class App < Sinatra::Base
    include ERB::Util
    before do
      @user = ENV['FAKE_CERTIFICATE_USER'] || env['SSL_CLIENT_S_DN_CN']
    end
  end
end
