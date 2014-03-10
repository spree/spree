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
require "spree/core/search/base"

module Spree
  class AppConfiguration < Preferences::Configuration

    attr_accessor :store

    # Alphabetized to more easily lookup particular preferences
    preference :address_requires_state, :boolean, default: true # should state/state_name be required
    preference :admin_interface_logo, :string, default: 'logo/spree_50.png'
    preference :admin_products_per_page, :integer, default: 10
    preference :allow_backorder_shipping, :boolean, default: false # should only be true if you don't need to track inventory
    preference :allow_checkout_on_gateway_error, :boolean, default: false
    preference :allow_guest_checkout, :boolean, default: true
    preference :allow_ssl_in_development_and_test, :boolean, default: false
    preference :allow_ssl_in_production, :boolean, default: true
    preference :allow_ssl_in_staging, :boolean, default: true
    preference :alternative_billing_phone, :boolean, default: false # Request extra phone for bill addr
    preference :alternative_shipping_phone, :boolean, default: false # Request extra phone for ship addr
    preference :always_include_confirm_step, :boolean, default: false # Ensures confirmation step is always in checkout_progress bar, but does not force a confirm step if your payment methods do not support it.
    preference :always_put_site_name_in_title, :boolean, default: true
    preference :auto_capture, :boolean, default: false # automatically capture the credit card (as opposed to just authorize and capture later)
    preference :binary_inventory_cache, :boolean, default: false # only invalidate product cache when a stock item changes whether it is in_stock
    preference :check_for_spree_alerts, :boolean, default: true
    preference :checkout_zone, :string, default: nil # replace with the name of a zone if you would like to limit the countries
    preference :company, :boolean, default: false # Request company field for billing and shipping addr
    preference :currency, :string, default: "USD"
    preference :currency_decimal_mark, :string, default: "."
    preference :currency_symbol_position, :string, default: "before"
    preference :currency_sign_before_symbol, :boolean, default: true
    preference :currency_thousands_separator, :string, default: ","
    preference :display_currency, :boolean, default: false
    preference :default_country_id, :integer
    preference :dismissed_spree_alerts, :string, default: ''
    preference :hide_cents, :boolean, default: false
    preference :last_check_for_spree_alerts, :string, default: nil
    preference :layout, :string, default: 'spree/layouts/spree_application'
    preference :logo, :string, default: 'logo/spree_50.png'
    preference :max_level_in_taxons_menu, :integer, default: 1 # maximum nesting level in taxons menu
    preference :orders_per_page, :integer, default: 15
    preference :prices_inc_tax, :boolean, default: false
    preference :products_per_page, :integer, default: 12
    preference :redirect_https_to_http, :boolean, :default => false
    preference :require_master_price, :boolean, default: true
    preference :shipment_inc_vat, :boolean, default: false
    preference :shipping_instructions, :boolean, default: false # Request instructions/info for shipping
    preference :show_only_complete_orders_by_default, :boolean, default: true
    preference :show_variant_full_price, :boolean, default: false #Displays variant full price or difference with product price. Default false to be compatible with older behavior
    preference :show_products_without_price, :boolean, default: false
    preference :show_raw_product_description, :boolean, :default => false
    preference :tax_using_ship_address, :boolean, default: true
    preference :track_inventory_levels, :boolean, default: true # Determines whether to track on_hand values for variants / products.

    # Default mail headers settings
    preference :enable_mail_delivery, :boolean, :default => false
    preference :send_core_emails, :boolean, :default => true
    preference :mails_from, :string, :default => 'spree@example.com'
    preference :mail_bcc, :string, :default => 'spree@example.com'
    preference :intercept_email, :string, :default => nil

    # Default smtp settings
    preference :override_actionmailer_config, :boolean, :default => true
    preference :mail_host, :string, :default => 'localhost'
    preference :mail_domain, :string, :default => 'localhost'
    preference :mail_port, :integer, :default => 25
    preference :secure_connection_type, :string, :default => Core::MailSettings::SECURE_CONNECTION_TYPES[0]
    preference :mail_auth_type, :string, :default => Core::MailSettings::MAIL_AUTH[0]
    preference :smtp_username, :string
    preference :smtp_password, :string

    # searcher_class allows spree extension writers to provide their own Search class
    def searcher_class
      @searcher_class ||= Spree::Core::Search::Base
    end

    def searcher_class=(sclass)
      @searcher_class = sclass
    end

    # This and the two aliases are only required while store prefs are beind deprecated
    def get_preference name
      name_sym = name.to_sym
      if DEPRECATED_STORE_PREFERENCES.include? name_sym
        ActiveSupport::Deprecation.warn("#{name} is no longer supported on Spree::Config, please access it through #{DEPRECATED_STORE_PREFERENCES[name_sym]} on Spree::Store")
        default_store.send(DEPRECATED_STORE_PREFERENCES[name_sym])
      else
        super(name)
      end
    end
    alias :get :get_preference
    alias :[] :get_preference

    private
    # all the following can be deprecated when store prefs are no longer supported
    DEPRECATED_STORE_PREFERENCES = {
      site_name: :name,
      site_url: :url,
      default_meta_description: :meta_description,
      default_meta_keywords: :meta_description,
      default_seo_title: :seo_title,
    }

    def default_store
      # hack to access preferences on stores if spun up before the database exists
      # safe to kill when all the Spree::Config access is gone
      return OpenStruct.new if @store.nil? && !ActiveRecord::Base.connection.table_exists?(Spree::Store.table_name)
      self.store ||= Spree::Store.first || Spree::Store.new
    end

    DEPRECATED_STORE_PREFERENCES.each do |old_preference_name, store_method|
      # support all the old preference methods through get_preference
      define_method old_preference_name, proc { self.get_preference old_preference_name }
      # this makes them still look like preferences
      define_method "preferred_#{old_preference_name.to_s}", proc {}
    end
  end
end
