Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins 'https://rip.ke'  # Replace with your specific URL
    resource '*', headers: :any, methods: :post
  end
end