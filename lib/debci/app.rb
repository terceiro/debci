require 'erubi'
require 'sinatra'
require 'erb'
require 'debci/user'

module Debci
  class App < Sinatra::Base
    set :erb, escape_html: true

    not_found do
      erb :not_found
    end

    include ERB::Util
    def read_request_user
      username = ENV['FAKE_CERTIFICATE_USER'] || env['SSL_CLIENT_S_DN_CN']
      Debci::User.find_or_create_by!(username: username) if username
    end

    def self.get_page_range(current, total)
      full_range = (1..total)
      middle = ((current - 5)..(current + 5)).select { |i| full_range.include?(i) }
      start = middle.include?(1) ? [] : [1, nil]
      finish = middle.include?(total) ? [] : [nil, total]
      start + middle + finish
    end

    def get_page_range(current, total)
      self.class.get_page_range(current, total)
    end
  end
end
