require 'sinatra'

module Debci

    class Web < Sinatra::Base
            
        set :views, root + "/web/views" 
        set :public_folder, File.dirname("config.ru") + "/public"

        get '/' do
            erb :index
        end

        if development?
            get '/doc' do 
                send_file File.join(settings.public_folder, '/doc/index.html')
            end
        end

        get '/packages/:package' do            
            erb :package
        end
        
    end
end
