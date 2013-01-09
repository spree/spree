module Spree
  module Dash
    class Engine < Rails::Engine
      isolate_namespace Spree
      engine_name 'spree_dash'

      initializer "spree.dash.environment", :before => :load_config_initializers do |app|
        Spree::Dash::Config = Spree::DashConfiguration.new
      end

      def self.activate
        Decorators.register! File.expand_path('../../../../', __FILE__)
      end
      config.to_prepare &method(:activate).to_proc

    end
  end
end
