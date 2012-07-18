module Spree
  module Dash
    class Engine < Rails::Engine
      isolate_namespace Spree
      engine_name 'spree_dash'

      initializer "spree.dash.environment", :before => :load_config_initializers do |app|
        Spree::Dash::Config = Spree::DashConfiguration.new
      end

      def self.activate
        Dir.glob(File.join(File.dirname(__FILE__), "../../../app/**/*_decorator*.rb")) do |c|
          Rails.configuration.cache_classes ? require(c) : load(c)
        end
      end
      config.to_prepare &method(:activate).to_proc

    end
  end
end
