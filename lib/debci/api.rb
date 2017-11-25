require 'digest/sha1'
require 'fileutils'
require 'json'
require 'securerandom'
require 'sinatra'
require "sinatra/namespace"

require 'debci'

module Debci

  class API < Sinatra::Base

    class KeyManager

      def key_path(user, keyname)
        keydir = File.join(Debci.config.secrets_dir, 'apikeys/user', user)
        File.join(keydir, Digest::SHA1.hexdigest(keyname))
      end

      def set_key(user, keyname)
        keyfile = key_path(user, keyname)
        FileUtils.mkdir_p(File.dirname(keyfile))
        key = SecureRandom.uuid
        File.open(keyfile, 'w', 0600) do |f|
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
        validate_packages(*tests.map { |t| t["package"] })
        tests.each do |test|
          cmdline = ['debci-enqueue', '--suite', suite, '--arch', arch]
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
        validate_packages(pkg)
        __system__('debci-enqueue', '--suite', suite, '--arch', arch, pkg)
        201
      end

    end

    protected

    def __system__(*args)
      system(*args)
    end

    def validate_packages(*pkgs)
      pkgs.each do |pkg|
        if Debci.blacklist.include?(pkg)
          halt(400, "Blacklisted package: #{pkg}\n")
        end
      end
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
      user = key_manager.authenticate(key)
      if user
        response['Auth-User'] = user
      else
        halt(403, "Invalid key")
      end
    end
  end

end
