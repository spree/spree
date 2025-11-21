# Default Admin Navigation Configuration
# This file defines the default sidebar and settings navigation for Spree Admin

Spree::Admin::Navigation.configure(:sidebar) do |nav|
  # Getting Started (onboarding)
  nav.add :getting_started,
          label: 'admin.getting_started',
          url: :admin_getting_started_path,
          icon: 'map',
          position: 5,
          if: -> { can?(:manage, current_store) && !current_store.setup_completed? },
          badge: -> { "#{current_store.setup_tasks_done}/#{current_store.setup_tasks_total}" },
          badge_class: 'badge-info',
          active: -> { controller_name == 'dashboard' && action_name == 'getting_started' }

  # Dashboard / Home
  nav.add :home,
          label: :home,
          url: :admin_path,
          icon: 'home',
          position: 10,
          active: -> { controller_name == 'dashboard' && action_name == 'show' }

  # Orders with submenu
  nav.add :orders,
          label: :orders,
          url: :admin_orders_path,
          icon: 'inbox',
          position: 20,
          active: -> { %w[orders checkouts].include?(controller_name) || @order&.present? || @parent&.is_a?(Spree::Order) },
          if: -> { can?(:manage, Spree::Order) },
          badge: -> {
            # Evaluated in view context with access to helper methods
            ready_to_ship_orders_count if ready_to_ship_orders_count&.positive?
          } do |orders|
    # Orders to Fulfill submenu
    orders.add :orders_to_fulfill,
               label: 'admin.orders.orders_to_fulfill',
               url: -> { spree.admin_orders_path(q: {shipment_state_not_in: [:shipped, :canceled]}) },
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
  nav.add :returns,
          label: :returns,
          url: :admin_customer_returns_path,
          icon: 'receipt-refund',
          position: 25,
          active: -> { %w[customer_returns return_authorizations].include?(controller_name) },
          if: -> { can?(:manage, Spree::CustomerReturn) || can?(:manage, Spree::ReturnAuthorization) } do |returns|
    # Return Authorizations
    returns.add :return_authorizations,
                label: :return_authorizations,
                url: :admin_return_authorizations_path,
                position: 10,
                if: -> { can?(:manage, Spree::ReturnAuthorization) }
  end

  # Products with submenu
  nav.add :products,
          label: :products,
          url: :admin_products_path,
          icon: 'package',
          position: 30,
          active: -> { %w[products external_categories taxons taxonomies option_types option_values properties stock_items stock_transfers variants digital_assets].include?(controller_name) },
          if: -> { can?(:manage, Spree::Product) } do |products|
    # Stock
    products.add :stock,
                 label: :stock,
                 url: :admin_stock_items_path,
                 position: 10,
                 active: -> { %w[stock_items stock_transfers].include?(controller_name) },
                 if: -> { can?(:manage, Spree::StockItem) || can?(:manage, Spree::StockTransfer) }

    # Taxonomies
    products.add :taxonomies,
                 label: :taxonomies,
                 url: :admin_taxonomies_path,
                 position: 20,
                 active: -> { %w[taxonomies taxons].include?(controller_name) },
                 if: -> { can?(:manage, Spree::Taxonomy) && can?(:manage, Spree::Taxon) }

    # Options
    products.add :options,
                 label: :options,
                 url: :admin_option_types_path,
                 position: 30,
                 active: -> { %w[option_types option_values].include?(controller_name) },
                 if: -> { can?(:manage, Spree::OptionType) }

    # Properties
    products.add :properties,
                 label: :properties,
                 url: :admin_properties_path,
                 position: 40,
                 if: -> { can?(:manage, Spree::Property) && Spree::Config.product_properties_enabled }
  end

  # Vendors (Enterprise Edition)
  nav.add :vendors,
          label: :vendors,
          url: 'https://spreecommerce.org/marketplace-ecommerce/',
          icon: 'heart-handshake',
          position: 35,
          if: -> { can?(:manage, current_store) && !defined?(SpreeEnterprise) },
          badge: 'Enterprise',
          tooltip: 'Multi-Vendor Marketplace is available in the Enterprise Edition',
          target: '_blank'

  # Customers with submenu
  nav.add :customers,
          label: :customers,
          url: :admin_users_path,
          icon: 'users',
          position: 40,
          active: -> { %w[users newsletter_subscribers].include?(controller_name) },
          if: -> { can?(:manage, Spree.user_class) } do |customers|
    # Newsletter Subscribers
    customers.add :newsletter_subscribers,
                  label: :newsletter_subscribers,
                  url: :admin_newsletter_subscribers_path,
                  position: 10
  end

  # Promotions with submenu
  nav.add :promotions,
          label: :promotions,
          url: :admin_promotions_path,
          icon: 'discount',
          position: 50,
          active: -> { %w[promotions gift_cards gift_card_batches coupon_codes].include?(controller_name) },
          if: -> { can?(:manage, Spree::Promotion) } do |promotions|
    # Gift Cards
    promotions.add :gift_cards,
                   label: :gift_cards,
                   url: :admin_gift_cards_path,
                   position: 10,
                   active: -> { %w[gift_cards gift_card_batches].include?(controller_name) }
  end

  # Reports
  nav.add :reports,
          label: :reports,
          url: :admin_reports_path,
          icon: 'chart-bar',
          position: 60,
          if: -> { can?(:manage, Spree::Report) }

  # Storefront with submenu
  nav.add :storefront,
          label: 'admin.storefront',
          url: :admin_themes_path,
          icon: 'building-store',
          position: 70,
          active: -> { %w[themes posts post_categories pages].include?(controller_name) || (controller_name == 'storefronts' && action_name == 'edit') },
          if: -> { can?(:manage, Spree::Theme) } do |storefront|
    # Themes
    storefront.add :themes,
                   label: :themes,
                   url: :admin_themes_path,
                   position: 10,
                   if: -> { can?(:manage, Spree::Theme) }

    # Pages
    storefront.add :pages,
                   label: :pages,
                   url: :admin_pages_path,
                   position: 20,
                   if: -> { can?(:manage, Spree::Page) }

    # Posts (Blog)
    storefront.add :posts,
                   label: :posts,
                   url: :admin_posts_path,
                   position: 30,
                   active: -> { %w[posts post_categories].include?(controller_name) },
                   if: -> { can?(:manage, Spree::Post) }

    # Storefront Settings
    storefront.add :storefront_settings,
                   label: :settings,
                   url: :edit_admin_storefront_path,
                   position: 40,
                   if: -> { can?(:manage, current_store) }
  end

  # Integrations
  nav.add :integrations,
          label: :integrations,
          url: :admin_integrations_path,
          icon: 'plug-connected',
          position: 80,
          if: -> { can?(:manage, Spree::Integration) }

  # Settings (bottom of sidebar)
  nav.add :settings,
          label: :settings,
          url: -> { spree.edit_admin_store_path(section: 'general-settings') },
          icon: 'settings',
          position: 100,
          if: -> { can?(:manage, current_store) }

  # Admin Users (bottom of sidebar)
  nav.add :admin_users,
          label: :users,
          url: :admin_admin_users_path,
          icon: 'users',
          position: 110,
          if: -> { can?(:manage, Spree.admin_user_class) }
end

# Settings Navigation
Spree::Admin::Navigation.configure(:settings) do |nav|
  # Store Details
  nav.add :general_settings,
          label: :store_details,
          url: -> { spree.edit_admin_store_path(section: 'general-settings') },
          icon: 'building-store',
          position: 10,
          active: -> { controller_name == 'stores' && params[:section] == 'general-settings' },
          if: -> { can?(:manage, current_store) }

  # Admin Users
  nav.add :users,
          label: :users,
          url: :admin_admin_users_path,
          icon: 'users',
          position: 20,
          active: -> { %w[admin_users invitations roles].include?(controller_name) },
          if: -> { can?(:manage, Spree.admin_user_class) }

  # Emails
  nav.add :emails,
          label: :emails,
          url: -> { spree.edit_admin_store_path(section: 'emails') },
          icon: 'send',
          position: 30,
          active: -> { controller_name == 'stores' && params[:section] == 'emails' },
          if: -> { can?(:manage, current_store) }

  # Policies
  nav.add :policies,
          label: :policies,
          url: :admin_policies_path,
          icon: 'list-check',
          position: 40,
          active: -> { controller_name == 'policies' },
          if: -> { can?(:manage, Spree::Policy) }

  # Checkout
  nav.add :checkout,
          label: :checkout,
          url: -> { spree.edit_admin_store_path(section: 'checkout') },
          icon: 'shopping-cart',
          position: 50,
          active: -> { controller_name == 'stores' && params[:section] == 'checkout' },
          if: -> { can?(:manage, current_store) }

  # Domains
  nav.add :domains,
          label: :domains,
          url: :admin_custom_domains_path,
          icon: 'world-www',
          position: 60,
          active: -> { controller_name == 'custom_domains' },
          if: -> { can?(:manage, Spree::CustomDomain) }

  # Payment Methods
  nav.add :payment_methods,
          label: :payments,
          url: :admin_payment_methods_path,
          icon: 'credit-card',
          position: 70,
          active: -> { controller_name == 'payment_methods' },
          if: -> { can?(:manage, Spree::PaymentMethod) }

  # Zones
  nav.add :zones,
          label: :zones,
          url: :admin_zones_path,
          icon: 'world',
          position: 80,
          active: -> { %w[zones countries states].include?(controller_name) },
          if: -> { can?(:manage, Spree::Zone) }

  # Shipping Methods
  nav.add :shipping_methods,
          label: :shipping,
          url: :admin_shipping_methods_path,
          icon: 'truck',
          position: 90,
          active: -> { %w[shipping_methods shipping_categories].include?(controller_name) },
          if: -> { can?(:manage, Spree::ShippingMethod) }

  # Tax Settings
  nav.add :tax_rates,
          label: :tax,
          url: :admin_tax_rates_path,
          icon: 'receipt-tax',
          position: 100,
          active: -> { %w[tax_rates tax_categories stripe_tax_registrations].include?(controller_name) },
          if: -> { can?(:manage, Spree::TaxRate) }

  # Returns
  nav.add :return_settings,
          label: :returns,
          url: :admin_return_authorization_reasons_path,
          icon: 'receipt-refund',
          position: 110,
          active: -> { %w[refund_reasons reimbursement_types return_authorization_reasons].include?(controller_name) },
          if: -> { can?(:manage, Spree::ReturnAuthorizationReason) }

  # Stock Locations
  nav.add :stock_locations,
          label: :stock_locations,
          url: :admin_stock_locations_path,
          icon: 'map-pin',
          position: 120,
          active: -> { controller_name == 'stock_locations' },
          if: -> { can?(:manage, Spree::StockLocation) }

  # Metafield Definitions
  nav.add :metafield_definitions,
          label: :metafield_definitions,
          url: :admin_metafield_definitions_path,
          icon: 'list-details',
          position: 130,
          active: -> { controller_name == 'metafield_definitions' },
          if: -> { can?(:manage, Spree::MetafieldDefinition) }

  # Audit Log
  nav.add :audits,
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
  nav.add :developers,
          label: :developers,
          url: :admin_oauth_applications_path,
          icon: 'terminal',
          position: 150,
          active: -> { %w[oauth_applications webhooks_subscribers].include?(controller_name) },
          if: -> { can?(:manage, Spree::OauthApplication) }

  # Edit Profile
  nav.add :edit_profile,
          label: 'admin.edit_profile',
          url: :edit_admin_profile_path,
          icon: 'user-scan',
          position: 200,
          active: -> { controller_name == 'profiles' && action_name == 'edit' }
end

# ===============================================
# Page Tab Navigations
# ===============================================

# Tax Tab Navigation
Spree::Admin::Navigation.configure(:tax_tabs) do |nav|
  nav.add :tax_rates,
          label: :tax_rates,
          url: :admin_tax_rates_path,
          position: 10,
          if: -> { can?(:manage, Spree::TaxRate) }

  nav.add :tax_categories,
          label: :tax_categories,
          url: :admin_tax_categories_path,
          position: 20,
          if: -> { can?(:manage, Spree::TaxCategory) }
end

# Shipping Tab Navigation
Spree::Admin::Navigation.configure(:shipping_tabs) do |nav|
  nav.add :shipping_methods,
          label: :shipping_methods,
          url: :admin_shipping_methods_path,
          position: 10,
          active: -> { controller_name == 'shipping_methods' && action_name == 'index' },
          if: -> { can?(:manage, Spree::ShippingMethod) }

  nav.add :shipping_categories,
          label: :shipping_categories,
          url: :admin_shipping_categories_path,
          position: 20,
          if: -> { can?(:manage, Spree::ShippingCategory) }
end

# Team Tab Navigation
Spree::Admin::Navigation.configure(:team_tabs) do |nav|
  nav.add :admin_users,
          label: :users,
          url: :admin_admin_users_path,
          position: 10,
          if: -> { can?(:manage, Spree.admin_user_class) }

  nav.add :invitations,
          label: :invitations,
          url: :admin_invitations_path,
          position: 20,
          if: -> { can?(:manage, Spree::Invitation) }

  nav.add :roles,
          label: :roles,
          url: :admin_roles_path,
          position: 30,
          if: -> { can?(:manage, Spree::Role) }
end

# Stock Tab Navigation
Spree::Admin::Navigation.configure(:stock_tabs) do |nav|
  nav.add :stock_items,
          label: :stock_items,
          url: :admin_stock_items_path,
          position: 10,
          active: -> { controller_name == 'stock_items' },
          if: -> { can?(:manage, Spree::StockItem) }

  nav.add :stock_transfers,
          label: :stock_transfers,
          url: :admin_stock_transfers_path,
          position: 20,
          active: -> { controller_name == 'stock_transfers' },
          if: -> { can?(:manage, Spree::StockTransfer) }
end

# Returns and Refunds Tab Navigation
Spree::Admin::Navigation.configure(:returns_tabs) do |nav|
  nav.add :return_authorization_reasons,
          label: :return_authorization_reasons,
          url: :admin_return_authorization_reasons_path,
          position: 10,
          if: -> { can?(:manage, Spree::ReturnAuthorizationReason) }

  nav.add :refund_reasons,
          label: :refund_reasons,
          url: :admin_refund_reasons_path,
          position: 20,
          if: -> { can?(:manage, Spree::RefundReason) }

  nav.add :reimbursement_types,
          label: :reimbursement_types,
          url: :admin_reimbursement_types_path,
          position: 30,
          if: -> { can?(:manage, Spree::ReimbursementType) }
end

# Developers Tab Navigation
Spree::Admin::Navigation.configure(:developers_tabs) do |nav|
  nav.add :api_keys,
          label: :api_keys,
          url: :admin_oauth_applications_path,
          position: 10,
          active: -> { controller_name == 'oauth_applications' },
          if: -> { can?(:manage, Spree::OauthApplication) }

  nav.add :webhooks,
          label: :webhooks,
          url: :admin_webhooks_subscribers_path,
          position: 20,
          active: -> { controller_name == 'webhooks_subscribers' },
          if: -> { can?(:manage, Spree::Webhooks::Subscriber) }
end

# Audit Tab Navigation
Spree::Admin::Navigation.configure(:audit_tabs) do |nav|
  nav.add :audit_log,
          label: 'admin.audit_log',
          url: :admin_audits_path,
          position: 10,
          active: -> { controller_name == 'audits' },
          if: -> { can?(:manage, current_store) }

  nav.add :exports,
          label: :exports,
          url: :admin_exports_path,
          position: 20,
          active: -> { controller_name == 'exports' },
          if: -> { can?(:manage, Spree::Export) }

  nav.add :imports,
          label: :imports,
          url: :admin_imports_path,
          position: 30,
          active: -> { controller_name == 'imports' },
          if: -> { can?(:manage, Spree::Import) }
end
