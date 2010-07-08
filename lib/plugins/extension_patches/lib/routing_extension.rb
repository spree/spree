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
        Extension.descendants.each do |ext|
          ext.route_definitions.each do |block|
            block.call(mapper)
          end
        end
      end
    
  end # RoutingExtension

  module RoutingExtensionMapper
  
    def load_extension_routes
      map = self
      paths_to_routes = Spree::ExtensionLoader.instance.load_extension_roots
      paths_to_routes.each do |routes_path|
        source = "#{routes_path}/config/routes.rb"
        if File.directory?("#{routes_path}/config")
          begin
            Rails.logger.info "INFO: Loading routes from #{source}"
            eval File.read(source) if File.file?(source)
          rescue LoadError, NameError => e
            $stderr.puts "Could not load routes from : #{source}.\n#{e.inspect}"
            nil
          end
        end
      end
    end
    
  end # RoutingExtensionMapper

end # Spree

ActionController::Routing::RouteSet.class_eval { include Spree::RoutingExtension }
ActionController::Routing::RouteSet::Mapper.class_eval { include Spree::RoutingExtensionMapper }
