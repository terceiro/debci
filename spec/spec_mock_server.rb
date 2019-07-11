def mock_server(route, service)
  Rack::Builder.new do
    map route do
      run service
    end
  end
end
