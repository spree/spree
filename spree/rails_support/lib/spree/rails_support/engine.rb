require 'rails/engine'

module Spree
  module RailsSupport
    class Engine < Rails::Engine
      isolate_namespace Spree
      engine_name 'spree_rails_support'

      initializer 'spree_rails_support.autoload', before: :set_autoload_paths do |app|
        app.config.autoload_paths += %W[#{root}/lib]
      end
    end
  end
end
