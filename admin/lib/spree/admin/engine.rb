require_relative 'runtime_configuration'

module Spree
  module Admin
    class Engine < ::Rails::Engine
      Environment = Struct.new(
        :admin_users_actions_partials,
        :admin_users_filters_partials,
        :admin_users_header_partials,
        :body_end_partials,
        :body_start_partials,
        :classifications_actions_partials,
        :classifications_header_partials,
        :coupon_codes_actions_partials,
        :coupon_codes_header_partials,
        :custom_domains_actions_partials,
        :custom_domains_header_partials,
        :customer_returns_actions_partials,
        :customer_returns_filters_partials,
        :customer_returns_header_partials,
        :dashboard_analytics_partials,
        :dashboard_sidebar_partials,
        :digital_assets_actions_partials,
        :digital_assets_header_partials,
        :exports_actions_partials,
        :exports_header_partials,
        :gift_cards_actions_partials,
        :gift_cards_filters_partials,
        :gift_cards_header_partials,
        :head_partials,
        :integrations_actions_partials,
        :integrations_header_partials,
        :invitations_actions_partials,
        :invitations_header_partials,
        :oauth_applications_actions_partials,
        :oauth_applications_header_partials,
        :option_types_actions_partials,
        :option_types_header_partials,
        :order_page_body_partials,
        :order_page_dropdown_partials,
        :order_page_header_partials,
        :order_page_sidebar_partials,
        :order_page_summary_partials,
        :orders_actions_partials,
        :orders_filters_partials,
        :orders_header_partials,
        :pages_actions_partials,
        :pages_header_partials,
        :payment_methods_actions_partials,
        :payment_methods_header_partials,
        :post_categories_actions_partials,
        :post_categories_header_partials,
        :posts_actions_partials,
        :posts_filters_partials,
        :posts_header_partials,
        :product_dropdown_partials,
        :product_page_title_partials,
        :product_form_partials,
        :product_form_sidebar_partials,
        :products_actions_partials,
        :products_filters_partials,
        :products_header_partials,
        :products_table_header_partials,
        :products_table_row_partials,
        :promotions_actions_partials,
        :promotions_filters_partials,
        :promotions_header_partials,
        :properties_actions_partials,
        :properties_header_partials,
        :refund_reasons_actions_partials,
        :refund_reasons_header_partials,
        :reimbursement_types_actions_partials,
        :reimbursement_types_header_partials,
        :reports_actions_partials,
        :reports_header_partials,
        :return_authorization_reasons_actions_partials,
        :return_authorization_reasons_header_partials,
        :return_authorizations_actions_partials,
        :return_authorizations_header_partials,
        :returns_and_refunds_nav_partials,
        :returns_nav_partials,
        :roles_actions_partials,
        :roles_header_partials,
        :settings_nav_partials,
        :shipping_categories_actions_partials,
        :shipping_categories_header_partials,
        :shipping_method_form_partials,
        :shipping_methods_actions_partials,
        :shipping_methods_header_partials,
        :shipping_nav_partials,
        :stock_items_actions_partials,
        :stock_items_filters_partials,
        :stock_items_header_partials,
        :stock_locations_actions_partials,
        :stock_locations_header_partials,
        :stock_nav_partials,
        :stock_transfers_actions_partials,
        :stock_transfers_filters_partials,
        :stock_transfers_header_partials,
        :store_credit_categories_actions_partials,
        :store_credit_categories_header_partials,
        :store_credits_actions_partials,
        :store_credits_header_partials,
        :store_form_partials,
        :store_nav_partials,
        :store_orders_nav_partials,
        :store_products_nav_partials,
        :store_settings_nav_partials,
        :storefront_nav_partials,
        :tax_categories_actions_partials,
        :tax_categories_header_partials,
        :tax_nav_partials,
        :tax_rates_actions_partials,
        :tax_rates_header_partials,
        :team_nav_partials,
        :taxonomies_actions_partials,
        :taxonomies_header_partials,
        :themes_actions_partials,
        :themes_header_partials,
        :user_dropdown_partials,
        :users_actions_partials,
        :users_filters_partials,
        :users_header_partials,
        :webhooks_subscribers_actions_partials,
        :webhooks_subscribers_header_partials,
        :vendors_nav_partials,
        :zones_actions_partials,
        :zones_header_partials
      )

      # accessible via Rails.application.config.spree_admin
      initializer 'spree.admin.environment', before: :load_config_initializers do |app|
        app.config.spree_admin = Environment.new
      end

      initializer 'spree.admin.configuration', before: :load_config_initializers do |_app|
        Spree::Admin::RuntimeConfig = Spree::Admin::RuntimeConfiguration.new
      end

      initializer 'spree.admin.dartsass_fix' do |app|
        if app.config.respond_to?(:assets) && defined?(Sprockets)
          # we're not using any sass compressors, as we're using dartsass-rails
          # some gems however like payment_icons still have sassc-rails as a dependency
          # which sets the css_compressor to :sass and breaks the assets pipeline
          app.config.assets.css_compressor = nil if app.config.assets.css_compressor == :sass
        end
      end

      # Rails 7.1 introduced a new feature that raises an error if a callback action is missing.
      # We need to disable it as we use a lot of concerns that add callback actions.
      initializer 'spree.admin.disable_raise_on_missing_callback_actions' do |app|
        app.config.action_controller.raise_on_missing_callback_actions = false
      end

      initializer 'spree.admin.assets' do |app|
        if app.config.respond_to?(:assets)
          app.config.assets.paths << root.join('app/javascript')
          app.config.assets.paths << root.join('vendor/javascript')
          app.config.assets.precompile += %w[ spree_admin_manifest bootstrap.bundle.min.js jquery3.min.js ] if defined?(Sprockets)
          # fix for TinyMCE-rails gem to work with both propshaft and sprockets
          app.config.assets.excluded_paths ||= [] if defined?(Sprockets)
        end
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
        Environment.new.tap do |env|
          env.members.each do |key|
            Rails.application.config.spree_admin.send("#{key}=", [])
          end
        end
      end
    end
  end
end
