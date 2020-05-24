require 'sinatra'
require 'erb'
require 'debci/user'

module Debci
  class App < Sinatra::Base
    include ERB::Util
    def read_request_user
      username = ENV['FAKE_CERTIFICATE_USER'] || env['SSL_CLIENT_S_DN_CN']
      Debci::User.find_or_create_by!(username: username) if username
    end
  end
end
