Spree::Core::Engine.add_routes do
  namespace :api, defaults: { format: 'json' } do
    namespace :v3 do
      namespace :admin do
        # One JSON-RPC message per request. Drawn inside the admin namespace so
        # the endpoint inherits the Admin API's authentication, rate limiting
        # and security headers rather than reimplementing them.
        post 'mcp', to: 'mcp#create'
      end

      namespace :store do
        # The shopper's surface: UCP-named tools over the Store API, and the
        # profile that tells an agent where to find them.
        post 'mcp', to: 'mcp#create'
        resource :ucp_profile, only: :show
      end
    end
  end
end
