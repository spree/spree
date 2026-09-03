# frozen_string_literal: true

require 'uri'

module Spree
  class Store < Spree.base_class
    has_prefix_id :store # Spree-specific: store

    include FriendlyId
    include Spree::TranslatableResource
    include Spree::HasCustomFields
    include Spree::Metadata
    include Spree::Stores::Setup
    include Spree::Stores::Markets
    include Spree::Stores::Channels
    include Spree::StoreDataSources
    include Spree::Security::Stores if defined?(Spree::Security::Stores)
    include Spree::UserManagement
    include Spree::OrderRouting::HasStrategyPreference
    include Spree::CaptureMethod

    #
    # Magic methods
    #
    acts_as_paranoid
    friendly_id :code, use: [:slugged], slug_column: :code, routes: :normal

    #
    # Translations
    #
    TRANSLATABLE_FIELDS = %i[name meta_description meta_keywords seo_title customer_support_email
                             address contact_phone].freeze
    translates(*TRANSLATABLE_FIELDS, column_fallback: Spree.mobility_column_fallback)
    self::Translation.class_eval do
      acts_as_paranoid
      # deleted translation values still need to be accessible - remove deleted_at scope
      default_scope { unscope(where: :deleted_at) }
    end

    #
    # Preferences
    #
    # general preferences
    preference :admin_locale, :string
    preference :timezone, :string, default: Time.zone.name
    preference :weight_unit, :string, default: 'lb'
    # Default package (Shopify-style): the box a store usually ships in.
    # Weight is the packaging tare (box + filler) added to every package's
    # content weight for rate calculation, in the store's weight unit; the
    # dimensions are the box itself, used verbatim by carrier rate providers
    # for dimensional-weight pricing — inches when the unit system is
    # imperial, centimeters when metric. Zeros keep historical behavior.
    preference :default_package_weight, :decimal, default: 0
    preference :default_package_length, :decimal, default: 0
    preference :default_package_width, :decimal, default: 0
    preference :default_package_height, :decimal, default: 0
    preference :unit_system, :string, default: 'imperial'
    # email preferences
    preference :send_consumer_transactional_emails, :boolean, default: true
    # Sellers are a different audience from shoppers, with their own reasons to
    # be silenced — a marketplace fronting its own seller comms turns these off
    # without also stopping customer receipts.
    preference :send_seller_transactional_emails, :boolean, default: true
    # Marketplace preferences
    #
    # VAT on the commission itself, as a fraction, when neither the rate nor
    # the tax provider names one. Zero by default: a marketplace outside the EU
    # charges no tax on its fee, and inventing one would overcharge sellers.
    preference :default_commission_tax_rate, :decimal, default: 0
    # Admit a seller the moment they finish the checklist, without waiting for
    # anyone to look at them. Off by default: a marketplace decides who trades
    # under its name, and letting that happen by omission is the wrong
    # default for the operator who never thought about it.
    preference :auto_approve_sellers, :boolean, default: false
    # Put a seller's product on sale the moment they submit it. Off for the
    # same reason as auto_approve_sellers: what the marketplace lists is what
    # it vouches for.
    preference :auto_approve_seller_products, :boolean, default: false
    # Who pays this store's sellers. Blank means core's record-only provider,
    # so a marketplace that has connected nothing still keeps a correct ledger
    # and settles by hand.
    preference :payout_provider, :string, default: nil
    # Refused at write time rather than silently falling back at read time: an
    # operator who mistypes a provider would otherwise get a bookkeeping-only
    # ledger and no indication anywhere that their choice was ignored.
    validates :preferred_payout_provider,
              inclusion: { in: ->(_store) { Spree.payout_providers.map(&:to_s) } }, allow_blank: true
    # How often sellers are settled, unless one carries its own schedule.
    # Monthly by default because it is the interval that needs least of an
    # operator paying by hand, which is what the built-in provider expects.
    preference :default_payouts_schedule_interval, :string, default: 'monthly'
    validates :preferred_default_payouts_schedule_interval,
              inclusion: { in: Spree::Seller::PAYOUT_INTERVALS }, allow_blank: true
    # What a seller's balance must reach before a settlement is worth sending;
    # below it the balance carries to the next period. Zero pays whatever is
    # owed, which is right for a provider that moves money for free.
    preference :default_minimum_payout_amount, :decimal, default: 0
    # Checkout preferences
    # Store-level fallback for the channel-owned `guest_checkout` preference
    # (see Spree::Channel::Gating). Retained so existing accessors keep working.
    preference :guest_checkout, :boolean, default: true
    # Store-level fallback for the channel-owned `storefront_access` posture.
    preference :storefront_access, :string, default: 'public'
    # Canonical storefront origin used in customer-facing emails and links,
    # e.g. "https://myshop.com" — see #storefront_url for the fallback chain.
    preference :storefront_url, :string
    preference :special_instructions_enabled, :boolean, default: false
    preference :stock_reservation_ttl_minutes, :integer, default: 10
    # Store-wide default for when a customer is charged rather than only
    # authorized. A payment method's own capture_method wins when set.
    # See Spree::CaptureMethod.
    preference :capture_method, :string, default: Spree::CaptureMethod::DEFAULT_CAPTURE_METHOD
    preference :stock_reservations_enabled, :boolean, default: true
    # Which address a sale's tax is computed against. Stores selling where tax
    # follows the destination keep this on; billing-address jurisdictions turn
    # it off.
    preference :tax_using_ship_address, :boolean, default: true
    # Where prices and stock levels come from. 'internal' is Spree's own
    # catalog and stock records; a connector gem registers others.
    preference :pricing_provider, :string, default: 'internal'
    preference :inventory_provider, :string, default: 'internal'
    # What happens when an external source cannot be reached.
    preference :pricing_provider_failure_policy, :string,
               default: Spree::ProviderFailurePolicy::DEFAULT_PRICING_POLICY
    preference :inventory_provider_failure_policy, :string,
               default: Spree::ProviderFailurePolicy::DEFAULT_INVENTORY_POLICY
    # Catalog preferences
    preference :track_inventory_levels, :boolean, default: true
    preference :show_products_without_price, :boolean, default: false
    preference :disable_sku_validation, :boolean, default: false
    # Records price changes so the storefront can show the lowest price of the
    # last 30 days, as the EU Omnibus Directive requires.
    preference :track_price_history, :boolean, default: true
    # Address preferences
    preference :company_field_enabled, :boolean, default: false
    # Showing the company field and requiring it are separate decisions: a
    # B2B store collects it from everyone, a mixed store only offers it.
    preference :address_requires_company, :boolean, default: false
    preference :address_requires_phone, :boolean, default: false
    # digital assets preferences
    preference :limit_digital_download_count, :boolean, default: true
    preference :limit_digital_download_days, :boolean, default: true
    preference :digital_asset_authorized_clicks, :integer, default: 5
    preference :digital_asset_authorized_days, :integer, default: 7
    preference :digital_asset_link_expire_time, :integer, default: 300
    # Class name of the Spree::OrderRouting::Strategy::Base subclass that
    # decides which StockLocation fulfills which items.
    preference :order_routing_strategy, :string, default: 'Spree::OrderRouting::Strategy::Rules'

    # Document numbering (docs/plans/6.0-document-numbers.md). The format
    # applies to every numbered document; prefix, suffix and starting value
    # are order-only — other document types keep their code-level prefixes.
    # Changes affect future numbers only; existing numbers are permanent.
    preference :document_number_format, :string, default: 'sequential'
    preference :order_number_prefix, :string, default: 'R'
    preference :order_number_suffix, :string, default: ''
    preference :order_number_sequence_start, :integer, default: 1001

    #
    # Associations
    #
    has_many :carts, class_name: 'Spree::Cart', inverse_of: :store, dependent: :destroy
    has_many :orders, class_name: 'Spree::Order'
    has_many :order_groups, class_name: 'Spree::OrderGroup'
    has_many :line_items, through: :orders, class_name: 'Spree::LineItem'
    has_many :digital_links, through: :line_items, class_name: 'Spree::DigitalLink'
    has_many :fulfillments, through: :orders, class_name: 'Spree::Fulfillment'
    has_many :shipments, through: :orders, class_name: 'Spree::Fulfillment', source: :fulfillments, deprecated: true
    has_many :payments, through: :orders, class_name: 'Spree::Payment'
    has_many :returns, class_name: 'Spree::Return', inverse_of: :store
    has_many :exchanges, class_name: 'Spree::Exchange', inverse_of: :store
    has_many :claims, class_name: 'Spree::Claim', inverse_of: :store
    has_many :return_reasons, class_name: 'Spree::ReturnReason', inverse_of: :store, dependent: :destroy
    has_many :claim_reasons, class_name: 'Spree::ClaimReason', inverse_of: :store, dependent: :destroy
    has_many :refund_reasons, class_name: 'Spree::RefundReason', inverse_of: :store, dependent: :destroy

    # :nullify (not :destroy) — clearing the collection must not cascade into
    # Promotion#not_used? / payment records; orphaned rows are detached, not deleted.
    has_many :payment_methods, class_name: 'Spree::PaymentMethod', dependent: :nullify

    has_many :products, class_name: 'Spree::Product', dependent: :nullify
    # The media library: every file uploaded to this store, whether or not it
    # has been placed on a product yet.
    has_many :media, class_name: 'Spree::Media', dependent: :destroy_async
    has_many :product_publications, through: :channels, source: :publications, class_name: 'Spree::ProductPublication'
    has_many :variants, through: :products, class_name: 'Spree::Variant', source: :variants
    has_many :stock_levels, through: :variants, class_name: 'Spree::StockLevel'
    has_many :prices, through: :variants, class_name: 'Spree::Price'
    has_many :price_lists, class_name: 'Spree::PriceList', inverse_of: :store
    has_many :fulfillment_items, through: :variants, class_name: 'Spree::FulfillmentItem'
    has_many :inventory_units, through: :variants, class_name: 'Spree::FulfillmentItem', source: :fulfillment_items, deprecated: true
    has_many :option_value_variants, through: :variants, class_name: 'Spree::OptionValueVariant'

    has_many :store_credits, class_name: 'Spree::StoreCredit'
    has_many :store_credit_events, through: :store_credits, class_name: 'Spree::StoreCreditEvent'

    # @deprecated Taxonomy is data-only in 6.0 and dropped in 6.1; use #categories.
    has_many :taxonomies, class_name: 'Spree::Taxonomy', deprecated: true
    has_many :categories, class_name: 'Spree::Category'
    has_many :collections, class_name: 'Spree::Collection', dependent: :destroy_async

    # restrict, not destroy — a type in use is refused deletion, so wiping a
    # store's types out from under its products would contradict that guard.
    has_many :product_types, class_name: 'Spree::ProductType', dependent: :restrict_with_error

    # The store's custom-field schema. Destroying a definition takes its values
    # with it, which is a large fan-out on a busy store, so it runs in a job.
    has_many :custom_field_definitions, class_name: 'Spree::CustomFieldDefinition',
             inverse_of: :store, dependent: :destroy_async

    # @deprecated Use #categories; removed in 6.1.
    def taxons
      Spree::Deprecation.warn('Spree::Store#taxons is deprecated and will be removed in Spree 6.1. Use #categories instead.')
      categories
    end

    def taxons=(value)
      Spree::Deprecation.warn('Spree::Store#taxons= is deprecated and will be removed in Spree 6.1. Use #categories= instead.')
      self.categories = value
    end

    # @deprecated Use {#stock_levels}; removed in 6.1.
    def stock_items
      Spree::Deprecation.warn('Spree::Store#stock_items is deprecated and will be removed in Spree 6.1. Use #stock_levels instead.')
      stock_levels
    end

    has_many :delivery_zones, class_name: 'Spree::DeliveryZone', dependent: :destroy
    has_many :delivery_methods, class_name: 'Spree::DeliveryMethod', dependent: :nullify
    has_many :delivery_profiles, class_name: 'Spree::DeliveryProfile', dependent: :destroy
    has_many :delivery_origin_groups, through: :delivery_profiles, class_name: 'Spree::DeliveryOriginGroup'

    # @return [Spree::DeliveryProfile, nil]
    def default_delivery_profile
      Spree::DeliveryProfile.default_for(self)
    end
    has_many :stock_locations, class_name: 'Spree::StockLocation', dependent: :nullify
    has_many :promotions, class_name: 'Spree::Promotion', dependent: :nullify

    has_many :tax_categories, class_name: 'Spree::TaxCategory', dependent: :destroy, inverse_of: :store
    has_many :tax_rates, class_name: 'Spree::TaxRate', dependent: :destroy, inverse_of: :store

    has_many :sellers, class_name: 'Spree::Seller', dependent: :destroy, inverse_of: :store
    has_many :commission_rates, class_name: 'Spree::CommissionRate', dependent: :destroy, inverse_of: :store
    # What this marketplace asks of a seller before it will let them trade.
    has_many :seller_requirements, -> { order(:position, :id) }, class_name: 'Spree::SellerRequirement',
                                                                dependent: :destroy, inverse_of: :store

    has_many :wishlists, class_name: 'Spree::Wishlist'

    has_many :data_feeds, class_name: 'Spree::DataFeed'

    # Countries are reference data, so this is a plain writer over the stored
    # code. Reading goes through Spree::Stores::Markets#default_country, which
    # prefers the default market's country when the store has markets.
    def default_country=(value)
      self[:default_country_code] = value&.iso
    end

    has_many :reports, class_name: 'Spree::Report'
    has_many :exports, class_name: 'Spree::Export'

    has_many :integrations, class_name: 'Spree::Integration'

    has_many :gift_cards, class_name: 'Spree::GiftCard', dependent: :destroy

    has_many :policies, class_name: 'Spree::Policy', dependent: :destroy, as: :owner

    has_many :webhook_endpoints, class_name: 'Spree::WebhookEndpoint', dependent: :destroy, inverse_of: :store
    has_many :webhook_deliveries, through: :webhook_endpoints, class_name: 'Spree::WebhookDelivery'

    has_many :channels, class_name: 'Spree::Channel', dependent: :destroy
    has_many :order_routing_rules, through: :channels, class_name: 'Spree::OrderRoutingRule'

    has_many :customer_groups, class_name: 'Spree::CustomerGroup', dependent: :destroy, inverse_of: :store

    has_many :companies, class_name: 'Spree::Company', dependent: :destroy, inverse_of: :store
    has_many :external_references, class_name: 'Spree::ExternalReference', dependent: :destroy, inverse_of: :store
    has_many :catalogs, class_name: 'Spree::Catalog', dependent: :destroy, inverse_of: :store

    has_many :api_keys, class_name: 'Spree::ApiKey', dependent: :destroy
    has_many :allowed_origins, class_name: 'Spree::AllowedOrigin', dependent: :destroy

    #
    # Validations
    #
    with_options presence: true do
      validates :name, :url, :mail_from_address, :code
    end
    validates :preferred_digital_asset_authorized_clicks, numericality: { only_integer: true, greater_than: 0 }
    validates :preferred_digital_asset_authorized_days, numericality: { only_integer: true, greater_than: 0 }
    # Sized for starting a transfer, not for keeping the file reachable — the
    # signed URL it governs is a bearer credential.
    validates :preferred_digital_asset_link_expire_time,
              numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 1.hour.to_i }
    validates :preferred_stock_reservation_ttl_minutes, numericality: { only_integer: true, greater_than: 0 }
    # A fraction, not a percentage: 0.21 is 21%. Bounded because the value is
    # multiplied straight into what a seller is charged, so a negative would
    # credit them and a figure above 1 would bill more tax than fee.
    validates :preferred_default_commission_tax_rate,
              numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }
    validates :preferred_storefront_access, inclusion: { in: Spree::Channel::Gating::STOREFRONT_ACCESS }
    validates :preferred_document_number_format,
              inclusion: { in: Spree::NumberGenerators::Registry::FORMATS.keys }
    validates :preferred_order_number_sequence_start,
              numericality: { only_integer: true, greater_than: 0 }
    validates :preferred_order_number_prefix, :preferred_order_number_suffix,
              length: { maximum: 10 },
              format: { with: /\A[A-Z0-9#-]*\z/,
                        message: :invalid_document_number_affix }
    validates :preferred_capture_method, inclusion: { in: Spree::CaptureMethod::CAPTURE_METHODS }
    validate :preferred_storefront_url_is_an_origin
    validate :order_number_sequence_start_unchanged_after_first_number, on: :update
    validates :mail_from_address, email: { allow_blank: false }
    validates :customer_support_email, email: { allow_blank: true }
    # FIXME: we should remove this condition in v5
    if !ENV['SPREE_DISABLE_DB_CONNECTION'] &&
       connected? &&
       table_exists? &&
       connection.column_exists?(:spree_stores, :new_order_notifications_email)
      validates :new_order_notifications_email, email: { allow_blank: true }
    end
    validates :mailer_logo, content_type: Rails.application.config.active_storage.web_image_content_types

    #
    # Attachments
    #
    has_one_attached :logo, service: Spree.public_storage_service_name
    has_one_attached :mailer_logo, service: Spree.public_storage_service_name

    # First-run setup credential (docs/plans/6.0-store-context-and-first-run-setup.md):
    # printed by the installer, only consulted by the setup endpoint while no
    # admin user exists, cleared when setup completes. Plaintext at rest —
    # same posture as invitation tokens, and only meaningful while the
    # database holds nothing but seed data.
    has_secure_token :setup_token

    # Link that claims this installation: the dashboard's first-run setup
    # screen with the store's token.
    # @return [String, nil] nil when no token is outstanding
    def setup_url
      return if setup_token.blank?

      "#{Spree::Stores::DashboardUrl.call(store: self)}/setup?token=#{setup_token}"
    end

    #
    # Callbacks
    before_validation :set_default_code, on: :create
    before_validation :normalize_preferred_storefront_url
    before_save :ensure_default_exists_and_is_unique
    after_create :create_default_policies
    after_create :create_default_delivery_profile

    #
    # Scopes
    #
    default_scope { order(created_at: :asc) }

    #
    # Delegations
    #

    def self.current(_url = nil)
      Spree::Current.store
    end

    # @return [Spree::Store, nil] the store flagged as default, if one exists
    def self.default
      where(default: true).first
    end

    def self.available_locales
      Spree::Store.default&.supported_locales_list || []
    end

    # Resolves the store's default channel via the +default+ boolean column
    # so promoting another channel in the admin takes effect immediately.
    # Falls back to the first active channel only for malformed data with no
    # flagged default.
    # @return [Spree::Channel, nil]
    def default_channel
      channels.default.first || channels.active.first
    end

    # Sets the stored code and seeds the country for the default market created
    # on store creation. Reading goes through Spree::Stores::Markets, which
    # prefers the default market's country once the store has markets.
    def default_country_code=(code)
      return if code.blank?

      country = Spree::Country.by_iso(code)
      return if country.nil?

      self[:default_country_code] = country.iso
      @default_country_for_market = country
    end

    # @deprecated Use +default_country_code=+. Removed in 6.1.
    def default_country_iso=(code)
      Spree::Deprecation.warn('Spree::Store#default_country_iso= is deprecated, use #default_country_code= instead')
      self.default_country_code = code
    end

    def unique_name
      @unique_name ||= "#{name} (#{code})"
    end

    # Who pays this store's sellers, ready to be asked.
    #
    # Who moves money to this store's sellers.
    #
    # Memoized per record, and cleared on reload — `reload` leaves plain
    # instance variables alone, so without that a provider holding its own
    # cache (Stripe's account lookups do) would answer from a snapshot taken
    # arbitrarily long ago, and an operator changing the setting would not be
    # picked up by a store object already in hand.
    #
    # @return [Spree::PayoutProvider::Base]
    def payout_provider_instance
      resolved = payout_provider_class
      # Keyed by the class it was built from, so changing the setting on a
      # store already in hand cannot keep answering with the old provider —
      # which would route real money through whoever was configured before.
      if @payout_provider_instance.nil? || @payout_provider_instance.class != resolved
        @payout_provider_instance = resolved.new
      end

      @payout_provider_instance
    end

    def reload(*)
      @payout_provider_instance = nil
      super
    end

    # The class alone, for the questions that are about the provider rather
    # than about a movement — there is no need to build one to ask what it
    # requires.
    #
    # @return [Class]
    def payout_provider_class
      configured = preferred_payout_provider.presence
      # A name no longer in the registry — a typo, or a gem since removed —
      # would otherwise raise inside a subscriber on every fulfillment and stop
      # the ledger recording anything. The built-in provider keeps the books
      # until an operator fixes the setting.
      configured = nil unless Spree.payout_providers.any? { |provider| provider.to_s == configured }

      (configured || Spree.default_payout_provider.to_s).constantize
    end

    def formatted_url
      @formatted_url ||= begin
        clean_url = url.to_s.sub(%r{^https?://}, '').split(':').first

        if Rails.env.development? || Rails.env.test?
          scheme = Rails.application.routes.default_url_options[:protocol] || :http
          port = Rails.application.routes.default_url_options[:port].presence || (Rails.env.development? ? 3000 : nil)

          if scheme.to_sym == :https
            URI::HTTPS.build(
              host: clean_url,
              port: port
            ).to_s
          else
            URI::HTTP.build(
              host: clean_url,
              port: port
            ).to_s
          end
        else
          URI::HTTPS.build(
            host: clean_url
          ).to_s
        end
      end
    end

    def url_or_custom_domain
      url
    end

    def formatted_url_or_custom_domain
      formatted_url
    end

    # Returns the storefront origin URL for use in customer-facing emails and links.
    # Uses the `storefront_url` preference when set, then the oldest non-loopback
    # allowed origin (the `http://localhost` origin seeded on install must never
    # leak into customer emails), otherwise falls back to formatted_url.
    #
    # @return [String] e.g. "https://myshop.com"
    def storefront_url
      preferred_storefront_url.presence ||
        allowed_origins.order(:created_at).reject(&:loopback?).first&.origin ||
        formatted_url
    end

    # Returns true if the given URL's origin matches one of the store's allowed origins.
    # See {Spree::AllowedOrigin#matches?} for the matching rules (scheme/host/port).
    #
    # @param url [String] the full URL to check
    # @return [Boolean]
    def allowed_origin?(url)
      return false if url.blank?

      allowed_origins.any? { |allowed_origin| allowed_origin.matches?(url) }
    end

    # Returns the states available for checkout for the store
    # @param country [Spree::Country] the country to get the states for
    # @return [Array<Spree::State>]
    def states_available_for_checkout(country)
      country.states.to_a
    end

    # Returns countries covered by delivery methods. Methods without delivery
    # zones are worldwide, so any such method means every country is covered;
    # otherwise coverage is the union of the attached zones' country, state,
    # and postal-code members.
    #
    # @return [ActiveRecord::Relation<Spree::Country>]
    def countries_with_shipping_coverage
      return Spree::Country.all.sort_by(&:name) if Spree::DeliveryMethod.where(delivery_zone_id: nil).exists?

      zone_ids = Spree::DeliveryMethod.where.not(delivery_zone_id: nil).select(:delivery_zone_id)

      # Every member carries its own country, including state members, so
      # coverage no longer has to resolve a subdivision back to its country.
      country_codes = Spree::DeliveryZoneMember.where(delivery_zone_id: zone_ids).
                      where.not(country_code: nil).distinct.pluck(:country_code)

      country_codes.filter_map { |code| Spree::Country.by_iso(code) }.sort_by(&:name)
    end

    # The store's own default stock location, created if it does not exist yet.
    #
    # Scoped to this store's first-party locations on both counts: unscoped it
    # answered with any store's default, and on a marketplace it would answer
    # with a seller's — putting the operator's stock on someone else's shelf.
    #
    # @return [Spree::StockLocation]
    def default_stock_location
      @default_stock_location ||= begin
        stock_location_scope = stock_locations.first_party.where(default: true)
        stock_location_scope.first || ActiveRecord::Base.connected_to(role: :writing) do
          stock_location_scope.create(default: true, name: Spree.t(:default_stock_location_name),
                                      country_code: default_country&.iso)
        end
      end
    end

    def metric_unit_system?
      preferred_unit_system == 'metric'
    end

    # A store is where capture settings bottom out, so it resolves to its own
    # preference. Payment methods layer their override on top of this.
    #
    # @return [String] one of Spree::CaptureMethod::CAPTURE_METHODS
    def resolved_capture_method
      preferred_capture_method.presence || Spree::CaptureMethod::DEFAULT_CAPTURE_METHOD
    end

    # @deprecated Use #preferred_capture_method; removed in 6.1.
    def preferred_auto_capture
      Spree::Deprecation.warn('Store#preferred_auto_capture is deprecated and will be removed in Spree 6.1. Use #preferred_capture_method instead.')
      capture_at_checkout?
    end

    # @deprecated Use #preferred_capture_method=; removed in 6.1.
    def preferred_auto_capture=(value)
      Spree::Deprecation.warn('Store#preferred_auto_capture= is deprecated and will be removed in Spree 6.1. Use #preferred_capture_method= instead.')
      # Turning it off only says "not at checkout" — it cannot distinguish
      # dispatch from manual, so an existing on_dispatch choice is preserved.
      self.preferred_capture_method = if value.to_b
                                        'checkout'
                                      elsif capture_at_checkout?
                                        'manual'
                                      else
                                        preferred_capture_method
                                      end
    end

    # @deprecated Use #preferred_capture_method; removed in 6.1.
    def preferred_auto_capture_on_dispatch
      Spree::Deprecation.warn('Store#preferred_auto_capture_on_dispatch is deprecated and will be removed in Spree 6.1. Use #preferred_capture_method instead.')
      capture_on_dispatch?
    end

    # @deprecated Use #preferred_capture_method=; removed in 6.1.
    def preferred_auto_capture_on_dispatch=(value)
      Spree::Deprecation.warn('Store#preferred_auto_capture_on_dispatch= is deprecated and will be removed in Spree 6.1. Use #preferred_capture_method= instead.')
      self.preferred_capture_method = if value.to_b
                                        'on_dispatch'
                                      elsif capture_on_dispatch?
                                        'manual'
                                      else
                                        preferred_capture_method
                                      end
    end

    private

    # Products without a profile fall back to this one, so it must exist
    # from the store's first moment.
    def create_default_delivery_profile
      Spree::DeliveryProfiles::Shipping.create!(store: self, name: 'General', default: true)
    end

    def create_default_policies
      Spree::Events.disable do
        [
          translate_with_store_locale_fallback('spree.terms_of_service'),
          translate_with_store_locale_fallback('spree.privacy_policy'),
          translate_with_store_locale_fallback('spree.returns_policy'),
          translate_with_store_locale_fallback('spree.shipping_policy')
        ].each do |policy_name|
          # Manual exists?/create to work around Mobility bug with find_or_create_by
          next if policies.with_matching_name(policy_name).exists?

          policies.create(name: policy_name)
        end
      end
    end

    # Translates a key using the store's default locale with fallback to :en
    def translate_with_store_locale_fallback(key)
      locale = default_locale.presence&.to_sym || :en
      I18n.t(key, locale: locale, default: I18n.t(key, locale: :en))
    end

    def ensure_default_exists_and_is_unique
      if default
        Spree::Store.where.not(id: id).update_all(default: false)
      elsif Spree::Store.where(default: true).count.zero?
        self.default = true
      end
    end

    def should_generate_new_friendly_id?
      false
    end

    # The very first store keeps the well-known 'default' code (tooling and
    # seeds reference it); every later store derives its code from the name,
    # suffixed until unique — a literal 'default' fallback would collide with
    # the unique index the moment a second store is created. Soft-deleted
    # stores still occupy their code (the unique index has no deleted_at
    # scope), so generation checks with_deleted.
    def set_default_code
      return if code.present?

      self.code =
        if Spree::Store.with_deleted.none?
          'default'
        else
          base = name.to_s.parameterize.presence || 'store'
          candidate = base
          sequence = 2
          while Spree::Store.with_deleted.exists?(code: candidate)
            candidate = "#{base}-#{sequence}"
            sequence += 1
          end
          candidate
        end
    end

    # The storefront URL preference must always hold a canonical origin — it
    # becomes the base for customer-email links and completes the storefront
    # setup task, and the v3 Admin API writes it without any controller-side
    # normalization. Parseable input is canonicalized here; garbage is left
    # in place for the validation below to reject.
    def normalize_preferred_storefront_url
      raw = preferred_storefront_url
      return if raw.blank?

      normalized = Spree::AllowedOrigin.normalize_origin(raw)
      self.preferred_storefront_url = normalized if normalized
    end

    def preferred_storefront_url_is_an_origin
      raw = preferred_storefront_url
      return if raw.blank?
      return if Spree::AllowedOrigin.normalize_origin(raw)

      errors.add(:preferred_storefront_url, :invalid)
    end

    # The starting value only shapes a counter that does not exist yet — once
    # the first number is issued the counter owns the value, so accepting a
    # change here would persist a setting that can never apply again. The
    # dashboard disables the field; this backs it for API clients.
    def order_number_sequence_start_unchanged_after_first_number
      return unless preferences_changed?

      default = preference_default(:order_number_sequence_start)
      old_value, new_value = changes['preferences'].map do |preferences_hash|
        ((preferences_hash || {})[:order_number_sequence_start] || default).to_i
      end
      return if old_value == new_value
      return unless Spree::NumberSequence.started?(store: self)

      errors.add(:preferred_order_number_sequence_start, :locked_after_first_number)
    end
  end
end
