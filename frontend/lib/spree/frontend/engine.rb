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

      initializer 'spree.frontend.checking_deprecated_preferences' do
        Spree::Frontend::Config.deprecated_preferences.each do |pref|
          # FIXME: we should only notify about deprecated preferences that are in use, not all of them
          # warn "[DEPRECATION] Spree::Frontend::Config[:#{pref[:name]}] is deprecated. #{pref[:message]}"
        end
      end
    end
  end
end
