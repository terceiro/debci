require 'debci/api'
require 'debci/self_service'

LISTING = <<~HTMLBLOCK.freeze
  <!DOCTYPE html>
  <html>
    <body>
    <h1>Index of <%= request.path %></h1>
    <div><a href="..">..</a></div>
    <% Dir.chdir(@dir) do %>
      <% Dir.glob('*').each do |f| %>
        <% h = File.directory?(f) ? f + '/': f %>
        <div><a href="<%= h %>"><%= f %></a></div>
      <% end %>
    <% end %>
    </body>
  </html>
HTMLBLOCK

class ServeStatic < Sinatra::Base
  def static!(*args)
    # XXX static! is a private method, so this could break at some point
    if request.path =~ /log\.gz$/
      headers['Content-Encoding'] = 'gzip'
      headers['Content-Type'] = 'text/plain; charset=utf-8'
    end
    super
  end

  get '/*' do
    return redirect("#{request.path}/") if request.path !~ %r{/$}

    index = File.join(settings.public_folder, request.path, 'index.html')
    if File.exist?(index)
      send_file(index, type: 'text/html')
    else
      @dir = File.dirname(index)
      if File.directory?(@dir)
        erb LISTING
      else
        halt(404, '<h1>404 Not Found</h1>')
      end
    end
  end
end

app = Rack::Builder.new do
  run ServeStatic if ENV['RACK_ENV'] == 'development'
  map '/api' do
    run Debci::API
  end
  map '/user' do
    run Debci::SelfService
  end
end

run app
