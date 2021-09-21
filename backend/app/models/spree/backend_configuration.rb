module Spree
  class BackendConfiguration < Preferences::Configuration
    preference :admin_path, :string, default: '/admin'
    preference :admin_products_per_page, :integer, default: Kaminari.config.default_per_page
    preference :admin_orders_per_page, :integer, default: Kaminari.config.default_per_page
    preference :admin_properties_per_page, :integer, default: Kaminari.config.default_per_page
    preference :admin_promotions_per_page, :integer, default: Kaminari.config.default_per_page
    preference :admin_customer_returns_per_page, :integer, default: Kaminari.config.default_per_page
    preference :admin_users_per_page, :integer, default: Kaminari.config.default_per_page
    preference :admin_show_version, :boolean, default: true
    preference :locale, :string, default: Rails.application.config.i18n.default_locale
    preference :variants_per_page, :integer, default: Kaminari.config.default_per_page
    preference :menus_per_page, :integer, default: Kaminari.config.default_per_page
    preference :product_wysiwyg_editor_enabled, :boolean, default: true
    preference :taxon_wysiwyg_editor_enabled, :boolean, default: true
    preference :show_only_complete_orders_by_default, :boolean, default: true

    ORDER_TABS         ||= [:orders, :payments, :creditcard_payments,
                            :shipments, :credit_cards, :return_authorizations,
                            :customer_returns, :adjustments, :customer_details]
    PRODUCT_TABS       ||= [:products, :option_types, :properties, :prototypes,
                            :variants, :product_properties, :taxonomies,
                            :taxons]
    REPORT_TABS        ||= [:reports]
    CONFIGURATION_TABS ||= [:configurations, :general_settings, :tax_categories,
                            :tax_rates, :zones, :countries, :states,
                            :payment_methods, :shipping_methods,
                            :shipping_categories, :stock_transfers,
                            :stock_locations, :trackers, :refund_reasons,
                            :reimbursement_types, :return_authorization_reasons,
                            :stores]
    PROMOTION_TABS     ||= [:promotions, :promotion_categories]
    USER_TABS          ||= [:users]
  end
end
