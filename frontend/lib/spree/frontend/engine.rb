module Spree
  module Frontend
    class Engine < ::Rails::Engine
      config.middleware.use 'Spree::Frontend::Middleware::SeoAssist'

      # Prevent XSS but allow text formatting
      config.action_view.sanitized_allowed_tags = %w(a b del em i ins mark p small strong sub sup)
      config.action_view.sanitized_allowed_attributes = %w(href)

      # sets the manifests / assets to be precompiled, even when initialize_on_precompile is false
      initializer 'spree.assets.precompile', group: :all do |app|
        app.config.assets.precompile += %w[
          spree/frontend/all*
        ]
      end

      initializer 'spree.frontend.environment', before: :load_config_initializers do |_app|
        Spree::Frontend::Config = Spree::FrontendConfiguration.new
      end
    end
  end
end
