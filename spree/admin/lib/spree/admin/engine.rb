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
        :payment_method_form_partials,
        :payment_methods_header_partials,
        :post_categories_actions_partials,
        :post_categories_header_partials,
        :posts_actions_partials,
        :posts_filters_partials,
        :posts_header_partials,
        :price_lists_actions_partials,
        :price_lists_header_partials,
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
        :zones_header_partials,
        :navigation,
        :tables
      )

      class NavigationEnvironment
        def initialize
          @contexts = {}
        end

        # Register a new navigation context
        # @param name [Symbol] The name of the navigation context
        # @return [Spree::Admin::Navigation] The navigation instance
        def register_context(name)
          name = name.to_sym
          @contexts[name] ||= Spree::Admin::Navigation.new(name)
        end

        # Get a registered navigation context
        # @param name [Symbol] The name of the navigation context
        # @return [Spree::Admin::Navigation] The navigation instance
        # @raise [NoMethodError] if the context hasn't been registered
        def get_context(name)
          name = name.to_sym
          @contexts[name] || raise(NoMethodError, "Navigation context '#{name}' has not been registered. Use Spree.admin.navigation.register_context(:#{name}) first.")
        end

        # List all registered contexts
        # @return [Array<Symbol>] Array of registered context names
        def contexts
          @contexts.keys
        end

        # Check if a context exists
        # @param name [Symbol] The context name to check
        # @return [Boolean] true if the context is registered
        def context?(name)
          @contexts.key?(name.to_sym)
        end

        # Define accessor methods for predefined and custom contexts
        def method_missing(method_name, *args)
          if method_name.to_s.end_with?('=')
            super
          else
            get_context(method_name)
          end
        end

        def respond_to_missing?(method_name, include_private = false)
          method_name.to_s.end_with?('=') ? false : context?(method_name)
        end
      end

      class TablesEnvironment
        def initialize
          @registries = {}
        end

        # Register a new table
        # @param name [Symbol] The name of the table (e.g., :products, :orders)
        # @param model_class [Class, nil] The model class for this table
        # @param search_param [Symbol] The ransack parameter for text search (default: :name_cont)
        # @param search_placeholder [String, nil] Custom placeholder for search field
        # @param row_actions [Boolean] Whether to show row actions (default: false)
        # @param row_actions_edit [Boolean] Whether to show edit button in row actions (default: true)
        # @param row_actions_delete [Boolean] Whether to show delete button in row actions (default: false)
        # @param new_resource [Boolean] Whether to show "Create new" button in empty state (default: true)
        # @param date_range_param [Symbol, nil] Ransack parameter base for date range filter (e.g., :completed_at)
        # @param date_range_label [String, nil] Label for date range filter
        # @param link_to_action [Symbol] Action to link to for :link columns (:edit or :show, default: :edit)
        # @return [Spree::Admin::Table] The table instance
        def register(name, model_class: nil, search_param: :name_cont, search_placeholder: nil, row_actions: false, row_actions_edit: true, row_actions_delete: false, new_resource: true, date_range_param: nil, date_range_label: nil, link_to_action: :edit)
          name = name.to_sym
          @registries[name] ||= Spree::Admin::Table.new(
            name,
            key: name,
            model_class: model_class,
            search_param: search_param,
            search_placeholder: search_placeholder,
            row_actions: row_actions,
            row_actions_edit: row_actions_edit,
            row_actions_delete: row_actions_delete,
            new_resource: new_resource,
            date_range_param: date_range_param,
            date_range_label: date_range_label,
            link_to_action: link_to_action
          )
        end

        # Get a registered table
        # @param name [Symbol] The name of the table
        # @return [Spree::Admin::Table] The table instance
        # @raise [NoMethodError] if the table hasn't been registered
        def get(name)
          name = name.to_sym
          @registries[name] || raise(NoMethodError, "Table '#{name}' has not been registered. Use Spree.admin.tables.register(:#{name}) first.")
        end

        # Check if a table is registered
        # @param name [Symbol] The table name
        # @return [Boolean]
        def registered?(name)
          @registries.key?(name.to_sym)
        end

        # List all registered tables
        # @return [Array<Symbol>]
        def registries
          @registries.keys
        end

        # Define accessor methods for registered tables
        def method_missing(method_name, *args)
          if method_name.to_s.end_with?('=')
            super
          else
            get(method_name)
          end
        end

        def respond_to_missing?(method_name, include_private = false)
          method_name.to_s.end_with?('=') ? false : registered?(method_name)
        end
      end

      # Add app/subscribers to autoload paths
      config.paths.add 'app/subscribers', eager_load: true

      # accessible via Rails.application.config.spree_admin
      initializer 'spree.admin.environment', before: :load_config_initializers do |app|
        app.config.spree_admin = Environment.new
      end

      initializer 'spree.admin.configuration', before: :load_config_initializers do |_app|
        Spree::Admin::RuntimeConfig = Spree::Admin::RuntimeConfiguration.new
      end

      # Rails 7.1 introduced a new feature that raises an error if a callback action is missing.
      # We need to disable it as we use a lot of concerns that add callback actions.
      initializer 'spree.admin.disable_raise_on_missing_callback_actions' do |app|
        app.config.action_controller.raise_on_missing_callback_actions = false
      end

      initializer 'spree.admin.tailwind_path', before: :load_config_initializers do
        ENV['SPREE_ADMIN_PATH'] ||= root.to_s
      end

      initializer 'spree.admin.assets' do |app|
        if app.config.respond_to?(:assets)
          app.config.assets.paths << root.join('app/javascript')
          app.config.assets.paths << root.join('vendor/javascript')
          # Add host app's builds directory for compiled Tailwind CSS
          app.config.assets.paths << Rails.root.join('app/assets/builds')
          app.config.assets.precompile += %w[ spree_admin_manifest ] if defined?(Sprockets)
          # fix for TinyMCE-rails gem to work with both propshaft and sprockets
          app.config.assets.excluded_paths ||= [] if defined?(Sprockets)
        end
      end

      rake_tasks do
        load root.join('lib/tasks/tailwind.rake')
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

      config.after_initialize do |app|
        Environment.new.tap do |env|
          env.members.each do |key|
            Rails.application.config.spree_admin.send("#{key}=", [])
          end
        end

        # Register predefined navigation contexts
        app.config.spree_admin.navigation = NavigationEnvironment.new
        app.config.spree_admin.navigation.register_context(:sidebar)
        app.config.spree_admin.navigation.register_context(:settings)
        app.config.spree_admin.navigation.register_context(:tax_tabs)
        app.config.spree_admin.navigation.register_context(:shipping_tabs)
        app.config.spree_admin.navigation.register_context(:team_tabs)
        app.config.spree_admin.navigation.register_context(:stock_tabs)
        app.config.spree_admin.navigation.register_context(:returns_tabs)
        app.config.spree_admin.navigation.register_context(:developers_tabs)
        app.config.spree_admin.navigation.register_context(:audit_tabs)

        # Register tables environment
        app.config.spree_admin.tables = TablesEnvironment.new
      end

      # Add admin event subscribers
      config.after_initialize do
        Spree.subscribers.concat [
          Spree::Admin::ImportSubscriber,
          Spree::Admin::ImportRowSubscriber
        ]
      end
    end
  end
end
