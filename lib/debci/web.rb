require 'sinatra'
require 'debci'

module Debci

    class Web < Sinatra::Base

        set :views, root + "/web/views"
        set :public_folder, File.dirname("config.ru") + "/public"

        get '/' do
            erb :index
        end

        if development?
            get '/doc/' do
                send_file File.join(settings.public_folder, '/doc/index.html')
            end
        end

        get '/status' do
            erb :status
        end

        get '/packages/:package' do

            validatePackage()

            erb :package

        end

        # Browse packages by prefix
        get '/browse/:prefix' do
            erb :packagelist
        end

        # Package history page
        get '/packages/:package/:suite/:arch' do

            validatePackage()

            @package = params[:package]
            @suite = params[:suite]
            @arch = params[:arch]

            erb :history
        end

        # Redirect to the main page if a route was not found
        not_found do
            redirect '/'
        end

        def validatePackage()
            begin

                @repository = Debci::Repository.new
                @package = @repository.find_package("#{params[:package]}")

            rescue Debci::Repository::PackageNotFound
                redirect '/'
            end
        end
    end
end
