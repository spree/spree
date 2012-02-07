module Spree
  module Auth
    class Engine < Rails::Engine
      isolate_namespace Spree
      engine_name 'spree_auth'

      initializer "spree.auth.environment", :before => :load_config_initializers do |app|
        Spree::Auth::Config = Spree::AuthConfiguration.new
      end

      def self.activate
        Dir.glob(File.join(File.dirname(__FILE__), "../../../app/**/*_decorator*.rb")) do |c|
          Rails.configuration.cache_classes ? require(c) : load(c)
        end
      end

      config.to_prepare &method(:activate).to_proc
      ActiveRecord::Base.class_eval { include Spree::TokenResource }
    end
  end
end
