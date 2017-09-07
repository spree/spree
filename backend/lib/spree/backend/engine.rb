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

      # sets the manifests / assets to be precompiled, even when initialize_on_precompile is false
      initializer 'spree.assets.precompile', group: :all do |app|
        app.config.assets.paths << "#{Rails.root}/app/assets/fonts"
        app.config.assets.precompile << /\.(?:svg|eot|woff|ttf)$/

        app.config.assets.precompile += %w[
          spree/backend/all*
          spree/backend/address_states.js
          jquery.jstree/themes/spree/*
          select2_locale*
        ]
      end
    end
  end
end
