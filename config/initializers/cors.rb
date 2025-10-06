Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins 'http://localhost:4000', 'https://rip.ke', 'https://test.rip.ke', 'https://lee.rip.ke', 'https://montezuma.rip.ke', 'https://umash.rip.ke' # Replace with your specific URL
    resource '*', headers: :any, methods: :post
  end
end