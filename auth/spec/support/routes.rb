# This will include the routing helpers in the specs so that we can use
# cart_path and so on to get to the routes.
RSpec.configure do |c|
  c.include Spree::Core::Engine.routes.url_helpers
  c.include Spree::Auth::Engine.routes.url_helpers
end
