module Spree
  module Api
    class Engine < Rails::Engine
      isolate_namespace Spree
      engine_name 'spree_api'

      def self.activate
        Dir.glob(File.join(File.dirname(__FILE__), "../../../app/**/*_decorator*.rb")) do |c|
          Rails.configuration.cache_classes ? require(c) : load(c)
        end
      end

      config.autoload_paths += %W(#{config.root}/lib)
      config.to_prepare &method(:activate).to_proc
    end
  end
end

# add helper to all the base controllers
# Spree::BaseController includes Spree::Core::ControllerHelpers
require 'spree/core/controller_helpers'
class << Spree::Core::ControllerHelpers
  def included_with_analytics(receiver)
    included_without_analytics(receiver)
    receiver.send :helper, 'spree/analytics'
  end
  alias_method_chain :included, :analytics
end
