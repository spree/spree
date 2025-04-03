require_relative 'runtime_configuration'

module Spree
  module Admin
    class Engine < ::Rails::Engine
      Environment = Struct.new(
        :head_partials,
        :body_start_partials,
        :body_end_partials,
        :dashboard_analytics_partials,
        :dashboard_sidebar_partials,
        :product_dropdown_partials,
        :product_form_partials,
        :product_form_sidebar_partials,
        :products_filters_partials,
        :order_page_header_partials,
        :order_page_body_partials,
        :order_page_summary_partials,
        :order_page_sidebar_partials,
        :order_page_dropdown_partials,
        :orders_filters_partials,
        :store_form_partials,
        :store_nav_partials,
        :store_settings_nav_partials,
        :store_orders_nav_partials,
        :store_products_nav_partials
      )

      # accessible via Rails.application.config.spree_admin
      initializer 'spree.admin.environment', before: :load_config_initializers do |app|
        app.config.spree_admin = Environment.new
      end

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
        app.config.spree_admin.cache_sweepers = []

        app.config.spree_admin.importmap = Importmap::Map.new
        app.config.spree_admin.importmap.draw(root.join('config/importmap.rb'))
      end

      initializer 'spree.admin.importmap.cache_sweeper', after: 'spree.admin.importmap' do |app|
        if app.config.importmap.sweep_cache && app.config.reloading_enabled?
          app.config.spree_admin.cache_sweepers << root.join('app/javascript')

          app.config.spree_admin.importmap.cache_sweeper(watches: app.config.spree_admin.cache_sweepers)

          ActiveSupport.on_load(:action_controller_base) do
            before_action { app.config.spree_admin.importmap.cache_sweeper.execute_if_updated }
          end
        end
      end

      config.after_initialize do
        Rails.application.config.spree_admin.head_partials = []
        Rails.application.config.spree_admin.body_start_partials = []
        Rails.application.config.spree_admin.body_end_partials = []
        Rails.application.config.spree_admin.dashboard_analytics_partials = []
        Rails.application.config.spree_admin.dashboard_sidebar_partials = []
        Rails.application.config.spree_admin.product_form_partials = []
        Rails.application.config.spree_admin.product_form_sidebar_partials = []
        Rails.application.config.spree_admin.product_dropdown_partials = []
        Rails.application.config.spree_admin.products_filters_partials = []
        Rails.application.config.spree_admin.order_page_header_partials = []
        Rails.application.config.spree_admin.order_page_body_partials = []
        Rails.application.config.spree_admin.order_page_sidebar_partials = []
        Rails.application.config.spree_admin.order_page_summary_partials = []
        Rails.application.config.spree_admin.order_page_dropdown_partials = []
        Rails.application.config.spree_admin.orders_filters_partials = []
        Rails.application.config.spree_admin.store_form_partials = []
        Rails.application.config.spree_admin.store_nav_partials = []
        Rails.application.config.spree_admin.store_settings_nav_partials = []
        Rails.application.config.spree_admin.store_orders_nav_partials = []
        Rails.application.config.spree_admin.store_products_nav_partials = []
      end
    end
  end
end
