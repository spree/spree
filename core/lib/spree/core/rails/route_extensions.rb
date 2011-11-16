module Spree
  module Core
    module Rails
      module RouteExtensions
        def spree(options={})
          routes = Array.wrap(options[:only]) || [:promo, :auth, :core]
          routes.each do |engine|
            mount "Spree::#{engine.to_s.classify}::Engine".constantize, :at => "/"
          end
        end
      end
    end
  end
end

ActionDispatch::Routing::Mapper.send :include, Spree::Core::Rails::RouteExtensions
