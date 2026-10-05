module Spree
  module Mcp
    class Engine < ::Rails::Engine
      isolate_namespace Spree
      engine_name 'spree_mcp'

      # Declares this endpoint as an OAuth protected resource, so a token can
      # be audience-bound to it and a client can discover the authorization
      # server from a 401 here.
      initializer 'spree.mcp.oauth_resource' do
        Spree::Api::Oauth.register_resource(:mcp, '/api/v3/admin/mcp')
      end
    end
  end
end
