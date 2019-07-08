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

    get '/test' do
      erb :self_service_test
    end

    post '/test/submit' do
      trigger = params[:trigger] || ''
      package = params[:package] || ''
      suite = params[:suite] || ''
      archs = (params[:arch] || []).reject(&:empty?)
      pin_packages = (params[:pin_packages] || '').split(/\n+|\r+/).reject(&:empty?)

      # assemble test request
      test_obj = {
        'trigger' => trigger,
        'package' => package
      }
      test_obj['pin-packages'] = []
      pin_packages.each do |pin_package|
        pin_package = pin_package.split(/,\s*/)
        test_obj['pin-packages'].push(pin_package)
      end
      test_request = {
        'archs' => archs,
        'suite' => suite,
        'tests' => [test_obj]
      }

      # validate inputs
      begin
        validate_form_submission(package, suite, archs)
        archs.each do |arch|
          request_tests(test_request['tests'], suite, arch, @user)
        end
      rescue StandardError => error
        @error_msg = error
        halt(400, erb(:self_service_test))
      end

      # user clicks on export to json
      if params[:export]
        content_type :json
        [200, [test_request].to_json]
      # user submits test
      else
        201
      end
    end

    def validate_form_submission(package, suite, archs)
      raise 'Please enter a valid package name' unless valid_package_name?(package)
      raise 'Please select a suite' if suite == ''
      raise 'Please select an architecture' if archs.empty?
    end
  end
end
