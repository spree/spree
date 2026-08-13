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
      preference :address_requires_state, :boolean, default: true, deprecated: 'State requirements now come from the address country - see Spree::Country#states_required'
      preference :address_requires_phone, :boolean, default: false, deprecated: 'Use the address_requires_phone preference in the Spree::Store model'
      preference :admin_url, :string, default: nil, deprecated: 'Use dashboard_url (or the SPREE_DASHBOARD_URL environment variable) instead — both name the origin where the dashboard is hosted.'
      # Origin where the React dashboard is hosted (e.g. `https://dashboard.shop.com`),
      # used for every link that sends someone into the dashboard: invitation
      # emails, the SSO callback, and the first-run setup link. Set
      # SPREE_DASHBOARD_URL in the environment rather than editing an
      # initializer — the setup link is printed by `db:seed`, before there is
      # any way to configure a running app.
      preference :dashboard_url, :string, default: nil, env: 'SPREE_DASHBOARD_URL'
      preference :allow_checkout_on_gateway_error, :boolean, default: false, deprecated: 'Nothing reads this in Spree 6 — completion checks whether payments cover the total, so a failed gateway call never completes an order'
      preference :allow_empty_price_amount, :boolean, default: false
      preference :allow_guest_checkout, :boolean, default: true, deprecated: true # this is only used in the rails frontend, and is not implemented in API
      preference :alternative_shipping_phone, :boolean, default: false, deprecated: 'Nothing reads this in Spree 6'
      preference :always_include_confirm_step, :boolean, default: false # Ensures confirmation step is always in checkout_progress bar, but does not force a confirm step if your payment methods do not support it.
      preference :always_put_site_name_in_title, :boolean, deprecated: true
      preference :always_use_translations, :boolean, default: false
      preference :auto_capture, :boolean, default: true, deprecated: 'Set it on the store instead' # automatically capture the credit card (as opposed to just authorize and capture later)
      preference :auto_capture_on_dispatch, :boolean, default: false, deprecated: 'Set it on the store instead' # Captures payment on dispatch rather than at checkout.
      preference :binary_inventory_cache, :boolean, default: false, deprecated: true # only invalidate product cache when a stock item changes whether it is in_stock
      preference :checkout_zone, :string, default: nil, deprecated: true # replace with the name of a zone if you would like to limit the countries
      preference :company, :boolean, default: false, deprecated: 'Use the company_field_enabled preference in the Spree::Store model' # Request company field for billing and shipping addr
      preference :currency, :string, default: 'USD', deprecated: true
      preference :credit_to_new_allocation, :boolean, default: false
      preference :disable_migration_check, :boolean, default: false # when turned on disables the startup warning about missing engine migrations
      preference :disable_sku_validation, :boolean, default: false, deprecated: 'Set it on the store instead' # when turned on disables the built-in SKU uniqueness validation
      preference :disable_store_presence_validation, :boolean, default: false, deprecated: true # when turned off disables Store presence validation for Products and Payment Methods
      preference :events_log_enabled, :boolean, default: true # Log all Spree events to Rails logger
      preference :expedited_exchanges, :boolean, default: false, deprecated: 'Exchanges are their own record in Spree 6 — see Spree::Exchange and the Exchanges::Fulfill workflow'
      preference :expedited_exchanges_days_window, :integer, default: 14, deprecated: 'Exchanges are their own record in Spree 6 — see Spree::Exchange and the Exchanges::Fulfill workflow'
      preference :geocode_addresses, :boolean, default: true
      preference :images_save_from_url_job_attempts, :integer, default: 5
      preference :max_image_download_size, :integer, default: 20_971_520 # 20 MB in bytes

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
      preference :products_per_page, :integer, default: 12, deprecated: 'Nothing reads this in Spree 6 — pass per_page to the API instead'
      preference :restock_inventory, :boolean, default: true, deprecated: 'Restocking is decided per line item by Spree::ReturnLineItem#resellable'
      preference :return_eligibility_number_of_days, :integer, default: 365, deprecated: 'Use the return_window_days preference on Spree::Market, or a returns.create.validate hook'
      preference :reserve_stock_on, :string, default: 'checkout', deprecated: 'Nothing reads this in Spree 6 — see the stock_reservations_enabled preference on the store'
      preference :stock_reservations_enabled, :boolean, default: true, deprecated: 'Set it on the store instead' # Hold stock during checkout to prevent overselling
      preference :default_stock_reservation_ttl_minutes, :integer, default: 10, deprecated: 'Use the stock_reservation_ttl_minutes preference on the store'
      # Tiered cart-expiry reaper (docs/plans/6.0-cart-order-split.md Decision 5)
      preference :guest_cart_expiry_days, :integer, default: 30
      preference :customer_cart_expiry_days, :integer, default: 90
      preference :empty_cart_expiry_hours, :integer, default: 48
      preference :send_core_emails, :boolean, default: true, deprecated: true # Default mail headers settings
      preference :shipping_instructions, :boolean, deprecated: true
      preference :show_only_complete_orders_by_default, :boolean, deprecated: true
      preference :show_variant_full_price, :boolean, default: false, deprecated: 'Nothing reads this in Spree 6 — a storefront decides how it renders prices'
      preference :show_products_without_price, :boolean, default: false, deprecated: 'Set it on the store instead'
      preference :show_raw_product_description, :boolean, deprecated: true
      preference :tax_using_ship_address, :boolean, default: true
      preference :title_site_name_separator, :string, deprecated: true
      preference :track_inventory_levels, :boolean, default: true, deprecated: 'Set it on the store instead' # Determines whether to track on_hand values for variants / products.
      preference :track_price_history, :boolean, default: true, deprecated: 'Set it on the store instead' # Records price changes for Omnibus Directive compliance. Disable for non-EU stores.
      preference :price_history_retention_days, :integer, default: 30 # Days to retain price history records. Used by spree:price_history:prune rake task.
      preference :use_user_locale, :boolean, default: true

      # Sets the path used for products, taxons and pages.
      preference :storefront_products_path, :string, default: 'products', deprecated: 'Nothing reads this in Spree 6 — storefront routes are owned by the storefront'
      preference :storefront_taxons_path, :string, default: 't', deprecated: 'Nothing reads this in Spree 6 — storefront routes are owned by the storefront'
      preference :storefront_pages_path, :string, default: 'pages', deprecated: 'Nothing reads this in Spree 6 — storefront routes are owned by the storefront'

      # coupon codes
      preference :coupon_codes_web_limit, :integer, default: 500 # number of coupon codes to be generated in the web process, more than this will be generated in a background job
      preference :coupon_codes_total_limit, :integer, default: 5000 # the maximum number of coupon codes to be generated

      # password reset
      preference :admin_password_reset_expires_in, :integer, default: 15 # admin password reset token expiration time in minutes
      preference :customer_password_reset_expires_in, :integer, default: 15 # password reset token expiration time in minutes

      # account lockout
      preference :max_failed_login_attempts, :integer, default: 5 # failed login attempts before an account is locked
      preference :lockout_duration, :integer, default: 1800 # lockout duration in seconds (30 minutes)

      # password policy
      # NIST 800-63B recommends a length floor with no composition rules (no forced
      # symbols/digits, which push users toward predictable substitutions).
      preference :minimum_password_length, :integer, default: 8
      # bcrypt silently truncates past 72 bytes — without a cap a long passphrase and
      # its 72-byte prefix are the same password. A correctness guard, not policy.
      preference :maximum_password_length, :integer, default: ActiveModel::SecurePassword::MAX_PASSWORD_LENGTH_ALLOWED
      # To replace the policy itself, assign Spree.password_validator — a class,
      # not a preference.

      # gift cards
      preference :gift_card_batch_web_limit, :integer, default: 500 # number of gift card codes to be generated in the web process, more than this will be generated in a background job
      preference :gift_card_batch_limit, :integer, default: 50_000

      # imports
      preference :large_import_threshold, :integer, default: 500 # imports with more rows than this skip per-row UI broadcasts and use bulk processing

    end
  end
end
