#######################################################################################################
# Substantial portions of this code were adapted from the Radiant CMS project (http://radiantcms.org) #
#######################################################################################################

module Spree
  module RoutingExtension
  
    def self.included(base)
      base.class_eval do
        alias :draw_without_plugin_routes :draw
        alias :draw :draw_with_plugin_routes
        alias :rails_reload :reload
        alias :reload :force_reload
      end
    end

    def force_reload
      if RAILS_ENV == 'development'
        load!
      else
        rails_reload
      end
    end  
    
    def draw_with_plugin_routes   
      draw_without_plugin_routes do |mapper|
        yield mapper
        add_extension_routes(mapper)
      end
    end

    private
  
      def add_extension_routes(mapper)
        Extension.descendants.each do |ext|
          ext.route_definitions.each do |block|
            block.call(mapper)
          end
        end
      end
    
  end
end

ActionController::Routing::RouteSet.class_eval { include Spree::RoutingExtension }