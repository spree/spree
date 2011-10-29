module Spree
  module Dash
    class Engine < Rails::Engine
      isolate_namespace Spree
      engine_name 'spree_dash'
    end
  end
end