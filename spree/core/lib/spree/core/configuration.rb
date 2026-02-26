# This is the primary location for defining Spree Core preferences
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
require 'spree/core/preferences/configuration' # for compatibility reasons
require 'spree/core/preferences/runtime_configuration'
require 'spree/core/preferences/preferable'

module Spree
  module Core
    class Configuration < Preferences::RuntimeConfiguration
      # Alphabetized to more easily lookup particular preferences
      preference :address_requires_state, :boolean, default: true, deprecated: true # should state/state_name be required
      preference :address_requires_phone, :boolean, default: false # Determines whether we require phone in address
      preference :allow_checkout_on_gateway_error, :boolean, default: false
      preference :allow_empty_price_amount, :boolean, default: false
      preference :allow_guest_checkout, :boolean, default: true, deprecated: true # this is only used in the rails frontend, and is not implemented in API
      preference :alternative_shipping_phone, :boolean, default: false # Request extra phone for ship addr
      preference :always_include_confirm_step, :boolean, default: false # Ensures confirmation step is always in checkout_progress bar, but does not force a confirm step if your payment methods do not support it.
      preference :always_put_site_name_in_title, :boolean, deprecated: true
      preference :always_use_translations, :boolean, default: false
      preference :auto_capture, :boolean, default: true # automatically capture the credit card (as opposed to just authorize and capture later)
      preference :auto_capture_on_dispatch, :boolean, default: false # Captures payment for each shipment in Shipment#after_ship callback, and makes Shipment.ready when payment authorized.
      preference :binary_inventory_cache, :boolean, default: false, deprecated: true # only invalidate product cache when a stock item changes whether it is in_stock
      preference :checkout_zone, :string, default: nil, deprecated: true # replace with the name of a zone if you would like to limit the countries
      preference :company, :boolean, default: false, deprecated: 'Use the company_field_enabled preference in the Spree::Store model' # Request company field for billing and shipping addr
      preference :currency, :string, default: 'USD', deprecated: true
      preference :credit_to_new_allocation, :boolean, default: false
      preference :disable_migration_check, :boolean, default: false # when turned on disables the startup warning about missing engine migrations
      preference :disable_sku_validation, :boolean, default: false # when turned off disables the built-in SKU uniqueness validation
      preference :disable_store_presence_validation, :boolean, default: false # when turned off disables Store presence validation for Products and Payment Methods
      preference :events_log_enabled, :boolean, default: true # Log all Spree events to Rails logger
      preference :expedited_exchanges, :boolean, default: false # NOTE this requires payment profiles to be supported on your gateway of choice as well as a delayed job handler to be configured with activejob. kicks off an exchange shipment upon return authorization save. charge customer if they do not return items within timely manner.
      preference :expedited_exchanges_days_window, :integer, default: 14 # the amount of days the customer has to return their item after the expedited exchange is shipped in order to avoid being charged
      preference :geocode_addresses, :boolean, default: true
      preference :images_save_from_url_job_attempts, :integer, default: 5

      # Preprocessed product image variant sizes at 2x retina resolution.
      # These variants are generated on upload to reduce runtime processing.
      # When using spree_image_tag, pass variant option instead of width and height.
      #
      # Default sizes:
      #   mini (128x128)     - admin thumbnails, checkout line items
      #   small (256x256)    - cart/order items, gallery thumbnails
      #   medium (400x400)   - mobile listing, admin media
      #   large (720x720)    - product listing, mobile gallery
      #   xlarge (2000x2000) - gallery main, lightbox
      #
      # To customize, override in your initializer:
      #   Spree::Config.product_image_variant_sizes = {
      #     mini: [128, 128],
      #     small: [256, 256],
      #     # ... your custom sizes
      #   }
      attr_writer :product_image_variant_sizes

      def product_image_variant_sizes
        @product_image_variant_sizes ||= {
          mini: [128, 128],
          small: [256, 256],
          medium: [400, 400],
          large: [720, 720],
          xlarge: [2000, 2000],
          og_image: [1200, 630]
        }
      end
      preference :layout, :string, deprecated: 'Please use Spree::Frontend::Config[:layout] instead'
      preference :logo, :string, deprecated: true
      preference :mailer_logo, :string, deprecated: true
      preference :max_level_in_taxons_menu, :integer, deprecated: true
      preference :non_expiring_credit_types, :array, default: []
      preference :product_properties_enabled, :boolean, default: false # enable legacy product properties
      preference :products_per_page, :integer, default: 12
      preference :require_master_price, :boolean, default: false
      preference :restock_inventory, :boolean, default: true # Determines if a return item is restocked automatically once it has been received
      preference :return_eligibility_number_of_days, :integer, default: 365
      preference :send_core_emails, :boolean, default: true, deprecated: true # Default mail headers settings
      preference :shipping_instructions, :boolean, deprecated: true
      preference :show_only_complete_orders_by_default, :boolean, deprecated: true
      preference :show_variant_full_price, :boolean, default: false # Displays variant full price or difference with product price. Default false to be compatible with older behavior
      preference :show_products_without_price, :boolean, default: false
      preference :show_raw_product_description, :boolean, deprecated: true
      preference :tax_using_ship_address, :boolean, default: true
      preference :title_site_name_separator, :string, deprecated: true
      preference :track_inventory_levels, :boolean, default: true # Determines whether to track on_hand values for variants / products.
      preference :use_user_locale, :boolean, default: true

      # Sets the path used for products, taxons and pages.
      preference :storefront_products_path, :string, default: 'products'
      preference :storefront_taxons_path, :string, default: 't'
      preference :storefront_pages_path, :string, default: 'pages'

      # coupon codes
      preference :coupon_codes_web_limit, :integer, default: 500 # number of coupon codes to be generated in the web process, more than this will be generated in a background job
      preference :coupon_codes_total_limit, :integer, default: 5000 # the maximum number of coupon codes to be generated

      # gift cards
      preference :gift_card_batch_web_limit, :integer, default: 500 # number of gift card codes to be generated in the web process, more than this will be generated in a background job
      preference :gift_card_batch_limit, :integer, default: 50_000

      attr_writer :searcher_class
    end
  end
end
