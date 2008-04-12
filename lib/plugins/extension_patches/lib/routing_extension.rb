#######################################################################################################
# Substantial portions of this code were adapted from the Radiant CMS project (http://radiantcms.org) #
#######################################################################################################

module Spree
  module RoutingExtension
  
    def self.included(base)
      base.class_eval do
        alias :draw_without_plugin_routes :draw
        alias :draw :draw_with_plugin_routes
      end
    end
  
    def draw_with_plugin_routes
      draw_without_plugin_routes do |mapper|
        add_extension_routes(mapper)
        yield mapper
      end
    end

    private
  
      def add_extension_routes(mapper)
=begin
        Extension.descendants.each do |ext|
          ext.route_definitions.each do |block|
            block.call(mapper)
          end
        end
=end
      end
    
  end
end

ActionController::Routing::RouteSet.class_eval { include Spree::RoutingExtension }