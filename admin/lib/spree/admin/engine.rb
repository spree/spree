require_relative 'runtime_configuration'

module Spree
  module Admin
    class Engine < ::Rails::Engine
      initializer 'spree.admin.configuration', before: :load_config_initializers do |_app|
        Spree::Admin::RuntimeConfig = Spree::Admin::RuntimeConfiguration.new
      end

      initializer 'spree.admin.dartsass_fix' do |app|
        # we're not using any sass compressors, as we're using dartsass-rails
        # some gems however like payment_icons still have sassc-rails as a dependency
        # which sets the css_compressor to :sass and breaks the assets pipeline
        app.config.assets.css_compressor = nil if app.config.assets.css_compressor == :sass
      end

      # Rails 7.1 introduced a new feature that raises an error if a callback action is missing.
      # We need to disable it as we use a lot of concerns that add callback actions.
      initializer 'spree.admin.disable_raise_on_missing_callback_actions' do |app|
        app.config.action_controller.raise_on_missing_callback_actions = false
      end

      initializer 'spree.admin.assets' do |app|
        app.config.assets.paths << root.join('app/javascript')
        app.config.assets.paths << root.join('vendor/javascript')
        app.config.assets.precompile += %w[ spree_admin_manifest bootstrap.bundle.min.js jquery3.min.js ]
      end

      initializer 'spree.admin.importmap', before: 'importmap' do |app|
        app.config.importmap.paths << root.join('config/importmap.rb')
        # https://github.com/rails/importmap-rails?tab=readme-ov-file#sweeping-the-cache-in-development-and-test
        app.config.importmap.cache_sweepers << root.join('app/javascript')
      end
    end
  end
end
