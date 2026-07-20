require 'rails/engine'

module Spree
  module Dashboard
    class Engine < Rails::Engine
      isolate_namespace Spree
      engine_name 'spree_dashboard'
    end
  end
end
