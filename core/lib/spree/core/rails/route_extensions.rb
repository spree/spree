module Spree
  module Core
    module Rails
      module RouteExtensions
        def spree(options={})
          engines = Array.wrap(options[:only]) if options[:only]
          engines ||= [:promo, :auth, :core]
          engines -= Array.wrap(options[:except])

          engines.map! { |r| r.to_s.classify }

          engines.each do |engine|
            if Spree.constants.include?(engine)
              mount "Spree::#{engine}::Engine".constantize, :at => "/"
            end
          end
        end
      end
    end
  end
end

ActionDispatch::Routing::Mapper.send :include, Spree::Core::Rails::RouteExtensions
