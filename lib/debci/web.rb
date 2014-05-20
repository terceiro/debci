require 'sinatra'

module Debci

    class Web < Sinatra::Base
            
        set :views, root + "/web/views" 
        set :public_folder, File.dirname("config.ru") + "/public"

        get '/' do
            erb :index
        end
        
    end
end
