require 'digest/sha1'
require 'fileutils'
require 'json'
require 'securerandom'
require 'sinatra'
require "sinatra/namespace"
require 'time'

require 'debci'
require 'debci/job'
require 'debci/key'

module Debci

  class API < Sinatra::Base

    register Sinatra::Namespace
    set :views, File.dirname(__FILE__) + '/api'

    attr_reader :suite, :arch, :user

    get '/' do
      redirect '/doc/file.API.html'
    end

    namespace '/v1' do

      get '/auth' do
        authenticate!
        200
      end

      get '/getkey' do
        erb :getkey
      end

      post '/getkey' do
        username = ENV['FAKE_CERTIFICATE_USER'] || env['SSL_CLIENT_S_DN_CN']
        if username
          key = Debci::Key.reset!(username)
          headers['Content-Type'] = 'text/plain'
          [201, key.key]
        else
          403
        end
      end

      get '/retry/:run_id' do
        erb :retry
      end

      post '/retry/:run_id' do
        username = ENV['FAKE_CERTIFICATE_USER'] || env['SSL_CLIENT_S_DN_CN']
        if not username
          authenticate!
        end
        run_id = params[:run_id]
        begin
          j = Debci::Job.find(run_id)
        rescue ActiveRecord::RecordNotFound => error
          halt(400, "Job ID not known: #{run_id}")
        end
        job = Debci::Job.create!(
          package: j.package,
          suite: j.suite,
          arch: j.arch,
          requestor: j.requestor,
          trigger: j.trigger,
          pin_packages: j.pin_packages,
        )
        self.enqueue(job)

        201
      end

      get '/test' do
        authenticate!
        jobs = Debci::Job.where(requestor: @user)
        if params[:since]
          since = Time.strptime(params[:since], '%s')
          jobs = jobs.where('updated_at >= ?', since)
        end
        data = {
          "until": jobs.map(&:created_at).max.to_i,
          "results": jobs,
        }
        headers['Content-Type'] = 'application/json'
        data.to_json
      end

      before '/test/:suite/:arch*'do
        authenticate!
        @suite = params[:suite]
        @arch = params[:arch]
        if !Debci.config.arch_list.include?(arch)
          halt(400, "Invalid architecture: #{arch}\n")
        elsif !Debci.config.suite_list.include?(suite)
          halt(400, "Invalid suite: #{suite}\n")
        end
      end


      post '/test/:suite/:arch' do
        tests = load_json(params[:tests])
        tests.each do |test|
          pkg = test['package']

          enqueue = true
          status = nil
          if Debci.blacklist.include?(pkg) || !valid_package_name?(pkg)
            enqueue = false
            status = 'fail'
          end

          job = Debci::Job.create!(
            package: pkg,
            suite: suite,
            arch: arch,
            requestor: @user,
            status: status,
            trigger: test['trigger'],
            pin_packages: test['pin-packages'],
          )

          self.enqueue(job) if enqueue
        end

        201
      end

      post '/test/:suite/:arch/:package' do
        pkg = params[:package]
        if Debci.blacklist.include?(pkg)
          halt(400, "Blacklisted package: #{pkg}\n")
        end
        if ! valid_package_name?(pkg)
          halt(400, "Invalid package name: #{pkg}\n")
        end

        job = Debci::Job.create!(
            package: pkg,
            suite: params[:suite],
            arch: params[:arch],
            requestor: @user,
        )
        self.enqueue(job)

        201
      end

    end

    protected

    def __system__(*args)
      system(*args)
    end

    def load_json(param)
      begin
        str = param.is_a?(Hash) && File.read(param[:tempfile]) || param
        JSON.load(str)
      rescue JSON::ParserError => error
        halt(400, "Invalid JSON: #{error}")
      end
    end

    def authenticate!
      key = env['HTTP_AUTH_KEY']
      @user = Debci::Key.authenticate(key)
      if @user
        response['Auth-User'] = @user
      else
        halt(403, "Invalid key\n")
      end
    end

    def enqueue(job)
      priority = 1
      job.enqueue(priority)
    end

    def valid_package_name?(pkg)
      self.class.valid_package_name?(pkg)
    end

    def self.valid_package_name?(pkg)
      pkg =~ %r{^[a-z0-9][a-z0-9+.-]+$}
    end

  end

end
