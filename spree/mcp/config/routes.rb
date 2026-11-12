Spree::Core::Engine.add_routes do
  namespace :api, defaults: { format: 'json' } do
    namespace :v3 do
      namespace :admin do
        # One JSON-RPC message per request. Drawn inside the admin namespace so
        # the endpoint inherits the Admin API's authentication, rate limiting
        # and security headers rather than reimplementing them.
        post 'mcp', to: 'mcp#create'
      end
    end
  end
end
