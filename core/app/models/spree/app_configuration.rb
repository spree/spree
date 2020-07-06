# This is the primary location for defining spree preferences
#
# The expectation is that this is created once and stored in
# the spree environment
#
# setters:
# a.color = :blue
# a[:color] = :blue
# a.set :color = :blue
# a.preferred_color = :blue
#
# getters:
# a.color
# a[:color]
# a.get :color
# a.preferred_color
#
require 'spree/core/search/base'

module Spree
  class AppConfiguration < Preferences::Configuration
    # Alphabetized to more easily lookup particular preferences
    preference :address_requires_state, :boolean, default: true # should state/state_name be required
    preference :address_requires_phone, :boolean, default: true # Determines whether we require phone in address
    preference :admin_interface_logo, :string, default: 'admin/logo.png'
    preference :admin_path, :string, default: '/admin'
    preference :admin_products_per_page, :integer, default: Kaminari.config.default_per_page
    preference :admin_orders_per_page, :integer, default: Kaminari.config.default_per_page
    preference :admin_properties_per_page, :integer, default: Kaminari.config.default_per_page
    preference :admin_promotions_per_page, :integer, default: Kaminari.config.default_per_page
    preference :admin_customer_returns_per_page, :integer, default: Kaminari.config.default_per_page
    preference :admin_users_per_page, :integer, default: Kaminari.config.default_per_page
    preference :admin_show_version, :boolean, default: true
    preference :allow_checkout_on_gateway_error, :boolean, default: false
    preference :allow_guest_checkout, :boolean, default: true
    preference :alternative_shipping_phone, :boolean, default: false # Request extra phone for ship addr
    preference :always_include_confirm_step, :boolean, default: false # Ensures confirmation step is always in checkout_progress bar, but does not force a confirm step if your payment methods do not support it.
    preference :always_put_site_name_in_title, :boolean, default: true
    preference :title_site_name_separator, :string, default: '-' # When always_put_site_name_in_title is true, insert a separator character before the site name in the title
    preference :auto_capture, :boolean, default: false # automatically capture the credit card (as opposed to just authorize and capture later)
    preference :auto_capture_on_dispatch, :boolean, default: false # Captures payment for each shipment in Shipment#after_ship callback, and makes Shipment.ready when payment authorized.
    preference :binary_inventory_cache, :boolean, default: false # only invalidate product cache when a stock item changes whether it is in_stock
    preference :checkout_zone, :string, default: nil # replace with the name of a zone if you would like to limit the countries
    preference :company, :boolean, default: false # Request company field for billing and shipping addr
    preference :currency, :string, default: 'USD'
    preference :default_country_id, :integer
    preference :disable_sku_validation, :boolean, default: false # when turned off disables the built-in SKU uniqueness validation
    preference :expedited_exchanges, :boolean, default: false # NOTE this requires payment profiles to be supported on your gateway of choice as well as a delayed job handler to be configured with activejob. kicks off an exchange shipment upon return authorization save. charge customer if they do not return items within timely manner.
    preference :expedited_exchanges_days_window, :integer, default: 14 # the amount of days the customer has to return their item after the expedited exchange is shipped in order to avoid being charged
    preference :layout, :string, default: 'spree/layouts/spree_application'
    preference :logo, :string, default: 'logo/spree_50.png'
    preference :mailer_logo, :string, default: 'logo/spree_50.png'
    preference :max_level_in_taxons_menu, :integer, default: 1 # maximum nesting level in taxons menu
    preference :products_per_page, :integer, default: 12
    preference :require_master_price, :boolean, default: true
    preference :restock_inventory, :boolean, default: true # Determines if a return item is restocked automatically once it has been received
    preference :return_eligibility_number_of_days, :integer, default: 365
    preference :send_core_emails, :boolean, default: true # Default mail headers settings
    preference :shipping_instructions, :boolean, default: false # Request instructions/info for shipping
    preference :show_only_complete_orders_by_default, :boolean, default: true
    preference :show_variant_full_price, :boolean, default: false # Displays variant full price or difference with product price. Default false to be compatible with older behavior
    preference :show_products_without_price, :boolean, default: false
    preference :show_raw_product_description, :boolean, default: false
    preference :tax_using_ship_address, :boolean, default: true
    preference :track_inventory_levels, :boolean, default: true # Determines whether to track on_hand values for variants / products.

    # Store credits configurations
    preference :non_expiring_credit_types, :array, default: []
    preference :credit_to_new_allocation, :boolean, default: false

    # Multi currency configurations
    preference :allow_currency_change,  :boolean, default: false
    preference :show_currency_selector, :boolean, default: false

    # searcher_class allows spree extension writers to provide their own Search class
    def searcher_class
      @searcher_class ||= Spree::Core::Search::Base
    end

    attr_writer :searcher_class
  end
end
