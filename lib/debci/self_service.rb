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
        @success = true
        [201, erb(:self_service_test)]
      end
    end

    def validate_form_submission(package, suite, archs)
      raise 'Please enter a valid package name' unless valid_package_name?(package)
      raise 'Please select a suite' if suite == ''
      raise 'Please select an architecture' if archs.empty?
    end

    post '/test/upload' do
      begin
        raise "Please select a JSON file to upload" if params[:tests].nil?
        test_requests = JSON.parse(File.read(params[:tests][:tempfile]))
        validate_json_submission(test_requests)

        # request tests
        test_requests.each do |request|
          request['arch'].each do |arch|
            request_tests(request['tests'], request['suite'], arch, @user)
          end
        end
      rescue JSON::ParserError => error
        halt(400, "Invalid JSON: #{error}")
      rescue StandardError => error
        @error_msg = error
        halt(400, erb(:self_service_test))
      else
        @success = true
        [201, erb(:self_service_test)]
      end
    end

    def validate_json_submission(test_requests)
      raise "Not an array" unless test_requests.is_a?(Array)
      errors = []
      test_requests.each_with_index do |request, index|
        request_suite = request['suite']
        errors.push("No suite at request index #{index}") if request_suite == ''
        errors.push("Wrong suite (#{request_suite}) at request index #{index}, available suites: #{settings.suites.join(', ')}") unless settings.suites.include?(request_suite)

        archs = request['arch'].reject(&:empty?)
        errors.push("No archs are specified at request index #{index}") if archs.empty?
        errors.push("Wrong archs (#{archs.join(', ')}) at request index #{index}, available archs: #{settings.archs.join(', ')}") if (settings.archs & archs).length != archs.length
        request['tests'].each_with_index do |t, i|
          errors.push("Invalid package name at request index #{index} and test index #{i}") unless valid_package_name?(t['package'])
        end
      end
      raise errors.join('<br>') unless errors.empty?
    end

    get '/history' do
      arch_filter = params[:arch]
      suite_filter = params[:suite]
      package_filter = params[:package] || ''
      trigger_filter = params[:trigger] || ''
      query = {
        requestor: @user
      }
      query[:arch] = arch_filter if arch_filter
      query[:suite] = suite_filter if suite_filter
      @history = Debci::Job.where(query)

      unless package_filter.empty?
        @history = @history.where("package LIKE :query", query: "%#{package_filter}%") unless package_filter.nil?
      end

      unless trigger_filter.empty?
        @history = @history.where("trigger LIKE :query", query: "%#{trigger_filter}%") unless trigger_filter.nil?
      end

      erb :self_service_history, locals: { arch_filter: arch_filter, suite_filter: suite_filter, package_filter: package_filter, trigger_filter: trigger_filter }
    end
  end
end
