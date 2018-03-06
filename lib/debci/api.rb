require 'digest/sha1'
require 'fileutils'
require 'json'
require 'securerandom'
require 'sinatra'
require "sinatra/namespace"
require 'time'

require 'debci'
require 'debci/job'

module Debci

  class API < Sinatra::Base

    class KeyManager

      def key_path(user, keyname)
        keydir = File.join(Debci.config.secrets_dir, 'apikeys/user', user)
        File.join(keydir, Digest::SHA1.hexdigest("#{user}::#{keyname}"))
      end

      def set_key(user, keyname)
        keyfile = key_path(user, keyname)
        FileUtils.mkdir_p(File.dirname(keyfile))
        key = SecureRandom.uuid
        File.open(keyfile, 'w', 0660) do |f|
          f.puts(key)
        end
        key
      end

      def authenticate(key)
        keyfiles = File.join(Debci.config.secrets_dir, 'apikeys/user/*/*')
        # FIXME this iterates over *all* present keys and is very inneficient
        Dir.glob(keyfiles).each do |keyfile|
          stored_key = File.read(keyfile).strip
          if key == stored_key
            user = File.basename(File.dirname(keyfile))
            return user
          end
        end
        nil
      end
    end

    register Sinatra::Namespace

    attr_reader :suite, :arch, :user

    get '/' do
      redirect '/doc/file.API.html'
    end

    namespace '/v1' do

      get '/auth' do
        authenticate!
        200
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
          if Debci.blacklist.include?(pkg)
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
          )

          next if !enqueue

          run_id = job.run_id.to_s
        
          cmdline = [
            'debci',
            'enqueue',
            '--suite', suite,
            '--arch', arch,
            '--requestor', @user,
            '--run-id', run_id,
          ]
          if test["trigger"]
            cmdline << "--trigger" << test["trigger"]
          end
          Array(test["pin-packages"]).each do |pin|
            pkg, suite = pin
            cmdline << "--pin-packages" << "#{suite}=#{pkg}"
          end
          cmdline << test["package"]
          __system__(*cmdline)
        end
        201
      end

      post '/test/:suite/:arch/:package' do
        pkg = params[:package]
        if Debci.blacklist.include?(pkg)
          halt(400, "Blacklisted package: #{pkg}\n")
        end

        job = Debci::Job.create!(
            package: pkg,
            suite: params[:suite],
            arch: params[:arch],
            requestor: @user,
        )

        run_id = job.run_id.to_s
        
        __system__(
          'debci',
          'enqueue',
          '--suite', suite,
          '--arch', arch,
          '--requestor', @user,
          '--run-id', run_id,
          pkg)
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

    def key_manager
      @key_manager ||= Debci::API::KeyManager.new
    end


    def authenticate!
      key = env['HTTP_AUTH_KEY']
      @user = key_manager.authenticate(key)
      if @user
        response['Auth-User'] = @user
      else
        halt(403, "Invalid key\n")
      end
    end

  end

end
