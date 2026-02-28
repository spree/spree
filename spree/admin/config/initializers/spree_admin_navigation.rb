# Default Admin Navigation Configuration
# This file defines the default sidebar and settings navigation for Spree Admin

Rails.application.config.after_initialize do
  # ===============================================
  # Sidebar Navigation
  # ===============================================
  sidebar_nav = Spree.admin.navigation.sidebar

  # Getting Started (onboarding)
  sidebar_nav.add :getting_started,
          label: 'admin.getting_started',
          url: :admin_getting_started_path,
          icon: 'map',
          position: 5,
          if: -> { current_store && can?(:manage, current_store) && !current_store.setup_completed? },
          badge: -> { "#{current_store.setup_tasks_done}/#{current_store.setup_tasks_total}" },
          badge_class: 'badge-info',
          active: -> { controller_name == 'dashboard' && action_name == 'getting_started' }

  # Dashboard / Home
  sidebar_nav.add :home,
          label: :home,
          url: :admin_path,
          icon: 'home',
          position: 10,
          active: -> { controller_name == 'dashboard' && action_name == 'show' }

  # Orders with submenu
  sidebar_nav.add :orders,
          label: :orders,
          url: :admin_orders_path,
          icon: 'inbox',
          position: 20,
          if: -> { can?(:manage, Spree::Order) },
          badge: -> {
            # Evaluated in view context with access to helper methods
            ready_to_ship_orders_count if ready_to_ship_orders_count&.positive?
          } do |orders|
    # Orders to Fulfill submenu
    orders.add :orders_to_fulfill,
              label: 'admin.orders.orders_to_fulfill',
              url: -> {
                query_state = {
                  id: 'root',
                  combinator: 'and',
                  filters: [
                    { id: 'f1', field: 'shipment_state', operator: 'not_in', value: [
                      { id: 'shipped', name: I18n.t('spree.shipment_states.shipped', default: 'Shipped') },
                      { id: 'canceled', name: I18n.t('spree.shipment_states.canceled', default: 'Canceled') }
                    ] }
                  ],
                  groups: []
                }.to_json
                spree.admin_orders_path(q: { shipment_state_not_in: ['shipped', 'canceled'] }, query_state: query_state)
              },
              position: 10,
              active: -> { controller_name == 'orders' && params.dig(:q, :shipment_state_not_in).present? },
              if: -> {
                ready_to_ship_orders_count&.positive?
              },
              badge: -> {
                ready_to_ship_orders_count if ready_to_ship_orders_count&.positive?
              }

    # Draft Orders
    orders.add :draft_orders,
              label: :draft_orders,
              url: :admin_checkouts_path,
              position: 20,
              active: -> { controller_name == 'checkouts' || (@order.present? && !@order.completed?) },
              if: -> { can?(:manage, :checkouts) }
  end

  # Returns with submenu
  sidebar_nav.add :returns,
          label: :returns,
          url: :admin_customer_returns_path,
          icon: 'receipt-refund',
          position: 25,
          if: -> { can?(:manage, Spree::CustomerReturn) || can?(:manage, Spree::ReturnAuthorization) } do |returns|
    # Return Authorizations
    returns.add :return_authorizations,
                label: :return_authorizations,
                url: :admin_return_authorizations_path,
                position: 10,
                if: -> { can?(:manage, Spree::ReturnAuthorization) }
  end

  # Products with submenu
  sidebar_nav.add :products,
          label: :products,
          url: :admin_products_path,
          icon: 'package',
          position: 30,
          if: -> { can?(:manage, Spree::Product) } do |products|

    # Price Lists
    products.add :price_lists,
                label: :price_lists,
                url: :admin_price_lists_path,
                position: 10,
                active: -> { %w[price_lists price_rules].include?(controller_name) },
                if: -> { can?(:manage, Spree::PriceList) }
    # Stock
    products.add :stock,
                label: :stock,
                url: :admin_stock_items_path,
                position: 20,
                active: -> { %w[stock_items stock_transfers].include?(controller_name) },
                if: -> { can?(:manage, Spree::StockItem) || can?(:manage, Spree::StockTransfer) }

    # Taxonomies
    products.add :taxonomies,
                label: :taxonomies,
                url: :admin_taxonomies_path,
                position: 30,
                active: -> { %w[taxonomies taxons].include?(controller_name) },
                if: -> { can?(:manage, Spree::Taxonomy) && can?(:manage, Spree::Taxon) }

    # Options
    products.add :options,
                label: :options,
                url: :admin_option_types_path,
                position: 40,
                active: -> { %w[option_types option_values].include?(controller_name) },
                if: -> { can?(:manage, Spree::OptionType) }

  end

  # Customers with submenu
  sidebar_nav.add :customers,
          label: :customers,
          url: :admin_users_path,
          icon: 'users',
          position: 40,
          if: -> { can?(:manage, Spree.user_class) } do |customers|
    # Customer Groups
    customers.add :customer_groups,
                  label: :customer_groups,
                  url: :admin_customer_groups_path,
                  position: 5,
                  active: -> { %w[customer_groups customer_group_users].include?(controller_name) },
                  if: -> { can?(:manage, Spree::CustomerGroup) }

    # Newsletter Subscribers
    customers.add :newsletter_subscribers,
                  label: :newsletter_subscribers,
                  url: :admin_newsletter_subscribers_path,
                  position: 10
  end

  # Promotions with submenu
  sidebar_nav.add :promotions,
          label: :promotions,
          url: :admin_promotions_path,
          icon: 'discount',
          position: 50,
          if: -> { can?(:manage, Spree::Promotion) } do |promotions|
    # Gift Cards
    promotions.add :gift_cards,
                  label: :gift_cards,
                  url: :admin_gift_cards_path,
                  position: 10,
                  active: -> { %w[gift_cards gift_card_batches].include?(controller_name) }
  end

  # Reports
  sidebar_nav.add :reports,
          label: :reports,
          url: :admin_reports_path,
          icon: 'chart-bar',
          position: 60,
          if: -> { can?(:manage, Spree::Report) }

  # Integrations
  sidebar_nav.add :integrations,
          label: :integrations,
          url: :admin_integrations_path,
          icon: 'plug-connected',
          position: 80,
          if: -> { can?(:manage, Spree::Integration) }

  # Section divider before settings
  sidebar_nav.add :settings_section,
          section_label: 'Settings',
          position: 90

  # Settings (bottom of sidebar)
  sidebar_nav.add :settings,
          label: :settings,
          url: -> { spree.edit_admin_store_path(section: 'general-settings') },
          icon: 'settings',
          position: 100,
          if: -> { can?(:manage, current_store) }

  # Admin Users (bottom of sidebar)
  sidebar_nav.add :admin_users,
          label: :users,
          url: :admin_admin_users_path,
          icon: 'users',
          position: 110,
          if: -> { can?(:manage, Spree.admin_user_class) }

  # ===============================================
  # Settings Navigation
  # ===============================================
  settings_nav = Spree.admin.navigation.settings

  # Store Details
  settings_nav.add :general_settings,
          label: :store_details,
          url: -> { spree.edit_admin_store_path(section: 'general-settings') },
          icon: 'building-store',
          position: 10,
          active: -> { controller_name == 'stores' && params[:section] == 'general-settings' },
          if: -> { can?(:manage, current_store) }

  # Admin Users
  settings_nav.add :users,
          label: :users,
          url: :admin_admin_users_path,
          icon: 'users',
          position: 20,
          active: -> { %w[admin_users invitations roles].include?(controller_name) },
          if: -> { can?(:manage, Spree.admin_user_class) }

  # Emails
  settings_nav.add :emails,
          label: :emails,
          url: -> { spree.edit_admin_store_path(section: 'emails') },
          icon: 'send',
          position: 30,
          active: -> { controller_name == 'stores' && params[:section] == 'emails' },
          if: -> { can?(:manage, current_store) }

  # Policies
  settings_nav.add :policies,
          label: :policies,
          url: :admin_policies_path,
          icon: 'list-check',
          position: 40,
          active: -> { controller_name == 'policies' },
          if: -> { can?(:manage, Spree::Policy) }

  # Payment Methods
  settings_nav.add :payment_methods,
          label: :payments,
          url: :admin_payment_methods_path,
          icon: 'credit-card',
          position: 70,
          active: -> { controller_name == 'payment_methods' },
          if: -> { can?(:manage, Spree::PaymentMethod) }

  # Markets
  settings_nav.add :markets,
          label: :markets,
          url: :admin_markets_path,
          icon: 'world',
          position: 78,
          active: -> { controller_name == 'markets' },
          if: -> { can?(:manage, Spree::Market) }

  # Zones
  settings_nav.add :zones,
          label: :zones,
          url: :admin_zones_path,
          icon: 'map-2',
          position: 80,
          active: -> { %w[zones countries states].include?(controller_name) },
          if: -> { can?(:manage, Spree::Zone) }

  # Shipping Methods
  settings_nav.add :shipping_methods,
          label: :shipping,
          url: :admin_shipping_methods_path,
          icon: 'truck',
          position: 90,
          active: -> { %w[shipping_methods shipping_categories].include?(controller_name) },
          if: -> { can?(:manage, Spree::ShippingMethod) }

  # Tax Settings
  settings_nav.add :tax_rates,
          label: :tax,
          url: :admin_tax_rates_path,
          icon: 'receipt-tax',
          position: 100,
          active: -> { %w[tax_rates tax_categories stripe_tax_registrations].include?(controller_name) },
          if: -> { can?(:manage, Spree::TaxRate) }

  # Returns
  settings_nav.add :return_settings,
          label: :returns,
          url: :admin_return_authorization_reasons_path,
          icon: 'receipt-refund',
          position: 110,
          active: -> { %w[refund_reasons reimbursement_types return_authorization_reasons].include?(controller_name) },
          if: -> { can?(:manage, Spree::ReturnAuthorizationReason) }

  # Stock Locations
  settings_nav.add :stock_locations,
          label: :stock_locations,
          url: :admin_stock_locations_path,
          icon: 'map-pin',
          position: 120,
          active: -> { controller_name == 'stock_locations' },
          if: -> { can?(:manage, Spree::StockLocation) }

  # Metafield Definitions
  settings_nav.add :metafield_definitions,
          label: :metafield_definitions,
          url: :admin_metafield_definitions_path,
          icon: 'list-details',
          position: 130,
          active: -> { controller_name == 'metafield_definitions' },
          if: -> { can?(:manage, Spree::MetafieldDefinition) }

  # Audit Log
  settings_nav.add :audits,
          label: 'admin.audit_log',
          url: :admin_audits_path,
          icon: 'history',
          position: 140,
          active: -> { %w[audits exports imports].include?(controller_name) },
          if: -> {
            # Only show if audits feature exists
            can?(:manage, current_store) &&
            Spree::Core::Engine.routes.url_helpers.respond_to?(:admin_audits_path)
          }

  # Developers
  settings_nav.add :developers,
          label: :developers,
          url: :admin_api_keys_path,
          icon: 'terminal',
          position: 150,
          active: -> { %w[oauth_applications api_keys webhooks_subscribers webhook_endpoints webhook_deliveries].include?(controller_name) },
          if: -> { can?(:manage, Spree::ApiKey) }

  # Edit Profile
  settings_nav.add :edit_profile,
          label: 'admin.edit_profile',
          url: :edit_admin_profile_path,
          icon: 'user-scan',
          position: 200,
          active: -> { controller_name == 'profile' && action_name == 'edit' }

  # ===============================================
  # Page Tab Navigations
  # ===============================================

  # Tax Tab Navigation
  tax_tabs_nav = Spree.admin.navigation.tax_tabs

  tax_tabs_nav.add :tax_rates,
          label: :tax_rates,
          url: :admin_tax_rates_path,
          position: 10,
          if: -> { can?(:manage, Spree::TaxRate) }

  tax_tabs_nav.add :tax_categories,
          label: :tax_categories,
          url: :admin_tax_categories_path,
          position: 20,
          if: -> { can?(:manage, Spree::TaxCategory) }

  # Shipping Tab Navigation
  shipping_tabs_nav = Spree.admin.navigation.shipping_tabs

  shipping_tabs_nav.add :shipping_methods,
          label: :shipping_methods,
          url: :admin_shipping_methods_path,
          position: 10,
          active: -> { controller_name == 'shipping_methods' && action_name == 'index' },
          if: -> { can?(:manage, Spree::ShippingMethod) }

  shipping_tabs_nav.add :shipping_categories,
          label: :shipping_categories,
          url: :admin_shipping_categories_path,
          position: 20,
          if: -> { can?(:manage, Spree::ShippingCategory) }

  # Team Tab Navigation
  team_tabs_nav = Spree.admin.navigation.team_tabs

  team_tabs_nav.add :admin_users,
          label: :users,
          url: :admin_admin_users_path,
          position: 10,
          if: -> { can?(:manage, Spree.admin_user_class) }

  team_tabs_nav.add :invitations,
          label: :invitations,
          url: :admin_invitations_path,
          position: 20,
          if: -> { can?(:manage, Spree::Invitation) }

  team_tabs_nav.add :roles,
          label: :roles,
          url: :admin_roles_path,
          position: 30,
          if: -> { can?(:manage, Spree::Role) }

  # Stock Tab Navigation
  stock_tabs_nav = Spree.admin.navigation.stock_tabs

  stock_tabs_nav.add :stock_items,
          label: :stock_items,
          url: :admin_stock_items_path,
          position: 10,
          active: -> { controller_name == 'stock_items' },
          if: -> { can?(:manage, Spree::StockItem) }

  stock_tabs_nav.add :stock_transfers,
          label: :stock_transfers,
          url: :admin_stock_transfers_path,
          position: 20,
          active: -> { controller_name == 'stock_transfers' },
          if: -> { can?(:manage, Spree::StockTransfer) }

  # Returns and Refunds Tab Navigation
  returns_tabs_nav = Spree.admin.navigation.returns_tabs

  returns_tabs_nav.add :return_authorization_reasons,
          label: :return_authorization_reasons,
          url: :admin_return_authorization_reasons_path,
          position: 10,
          if: -> { can?(:manage, Spree::ReturnAuthorizationReason) }

  returns_tabs_nav.add :refund_reasons,
          label: :refund_reasons,
          url: :admin_refund_reasons_path,
          position: 20,
          if: -> { can?(:manage, Spree::RefundReason) }

  returns_tabs_nav.add :reimbursement_types,
          label: :reimbursement_types,
          url: :admin_reimbursement_types_path,
          position: 30,
          if: -> { can?(:manage, Spree::ReimbursementType) }

  # Developers Tab Navigation
  developers_tabs_nav = Spree.admin.navigation.developers_tabs

  developers_tabs_nav.add :api_keys,
          label: :api_keys,
          url: :admin_api_keys_path,
          position: 10,
          active: -> { controller_name == 'api_keys' },
          if: -> { can?(:manage, Spree::ApiKey) }

  developers_tabs_nav.add :webhook_endpoints,
          label: :webhook_endpoints,
          url: :admin_webhook_endpoints_path,
          position: 20,
          active: -> { %w[webhook_endpoints webhook_deliveries].include?(controller_name) },
          if: -> { can?(:manage, Spree::WebhookEndpoint) }

  # Audit Tab Navigation
  audit_tabs_nav = Spree.admin.navigation.audit_tabs

  audit_tabs_nav.add :audit_log,
          label: 'admin.audit_log',
          url: :admin_audits_path,
          position: 10,
          active: -> { controller_name == 'audits' },
          if: -> { can?(:manage, current_store) }

  audit_tabs_nav.add :exports,
          label: :exports,
          url: :admin_exports_path,
          position: 20,
          active: -> { controller_name == 'exports' },
          if: -> { can?(:manage, Spree::Export) }

  audit_tabs_nav.add :imports,
          label: :imports,
          url: :admin_imports_path,
          position: 30,
          active: -> { controller_name == 'imports' },
          if: -> { can?(:manage, Spree::Import) }
end
