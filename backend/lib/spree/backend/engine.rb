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
    end
  end
end
