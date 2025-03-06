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

      initializer 'spree.admin.importmap', after: 'importmap' do |app|
        app.config.spree_admin = ActiveSupport::OrderedOptions.new

        app.config.spree_admin.importmap = Importmap::Map.new
        app.config.spree_admin.importmap.draw(root.join('config/importmap.rb'))

        if app.config.importmap.sweep_cache && app.config.reloading_enabled?
          app.config.spree_admin.importmap.cache_sweeper(watches: root.join("app/javascript"))

          ActiveSupport.on_load(:action_controller_base) do
            before_action { app.config.spree_admin.importmap.cache_sweeper.execute_if_updated }
          end
        end
      end
    end
  end
end
