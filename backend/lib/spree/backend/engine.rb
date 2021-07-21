module Spree
  module Backend
    class Engine < ::Rails::Engine
      config.middleware.use 'Spree::Backend::Middleware::SeoAssist'

      initializer 'spree.backend.environment', before: :load_config_initializers do |_app|
        Spree::Backend::Config = Spree::BackendConfiguration.new
      end

      # filter sensitive information during logging
      initializer 'spree.params.filter' do |app|
        app.config.filter_parameters += [:password, :password_confirmation, :number]
      end

      initializer 'spree.core.checking_deprecated_preferences' do
        Spree::Backend::Config.deprecated_preferences.each do |pref|
          warn "[DEPRECATION] Spree::Backend::Config[:#{pref[:name]}] is deprecated #{pref[:message]}"
        end
      end
    end
  end
end
