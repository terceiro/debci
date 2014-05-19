require 'sinatra'

module Debci

    class Web < Sinatra::Base
            
        set :views, root + "/web/views" 
        
        get '/' do
            erb :index
        end
        
    end
end
