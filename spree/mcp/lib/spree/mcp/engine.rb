module Spree
  module Mcp
    class Engine < ::Rails::Engine
      isolate_namespace Spree
      engine_name 'spree_mcp'
    end
  end
end

# The endpoint is drawn into the Admin API's own namespace rather than mounted
# separately, so it inherits that namespace's host constraints, rate limiting
# and security headers. Required here rather than left to Rails' engine route
# loading: `Spree::Core::Engine.add_routes` has to have collected the block
# before core draws its routes, which happens while core's own routes file
# loads.
require_relative '../../../config/routes'
