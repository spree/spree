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
    include Spree::Security::Stores if defined?(Spree::Security::Stores)
    include Spree::UserManagement
    include Spree::OrderRouting::HasStrategyPreference

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
    # Store-wide default for charging cards at checkout rather than only
    # authorizing them. A payment method's own auto_capture column wins when set.
    preference :auto_capture, :boolean, default: true
    preference :auto_capture_on_dispatch, :boolean, default: false
    preference :stock_reservations_enabled, :boolean, default: true
    # Catalog preferences
    preference :track_inventory_levels, :boolean, default: true
    preference :show_products_without_price, :boolean, default: false
    preference :disable_sku_validation, :boolean, default: false
    # Records price changes so the storefront can show the lowest price of the
    # last 30 days, as the EU Omnibus Directive requires.
    preference :track_price_history, :boolean, default: true
    # Address preferences
    preference :company_field_enabled, :boolean, default: false
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

    #
    # Associations
    #
    has_many :carts, class_name: 'Spree::Cart', inverse_of: :store, dependent: :destroy
    has_many :checkouts, -> { incomplete }, class_name: 'Spree::Order', inverse_of: :store
    has_many :orders, class_name: 'Spree::Order'
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
    has_many :product_publications, through: :channels, source: :publications, class_name: 'Spree::ProductPublication'
    has_many :variants, through: :products, class_name: 'Spree::Variant', source: :variants
    has_many :stock_items, through: :variants, class_name: 'Spree::StockItem'
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

    # @deprecated Use #categories; removed in 6.1.
    def taxons
      Spree::Deprecation.warn('Spree::Store#taxons is deprecated and will be removed in Spree 6.1. Use #categories instead.')
      categories
    end

    def taxons=(value)
      Spree::Deprecation.warn('Spree::Store#taxons= is deprecated and will be removed in Spree 6.1. Use #categories= instead.')
      self.categories = value
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

    has_many :wishlists, class_name: 'Spree::Wishlist'

    has_many :data_feeds, class_name: 'Spree::DataFeed'

    belongs_to :default_country, class_name: 'Spree::Country'
    belongs_to :checkout_zone, class_name: 'Spree::Zone'

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
    validates :preferred_stock_reservation_ttl_minutes, numericality: { only_integer: true, greater_than: 0 }
    validates :preferred_storefront_access, inclusion: { in: Spree::Channel::Gating::STOREFRONT_ACCESS }
    validate :preferred_storefront_url_is_an_origin
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

    # @deprecated Use Markets instead. Will be removed in Spree 5.5.
    def checkout_zone
      Spree::Deprecation.warn('Store#checkout_zone is deprecated and will be removed in Spree 5.5. Use Markets instead.')
      super
    end

    # @deprecated Use Markets instead. Will be removed in Spree 5.5.
    def checkout_zone=(zone)
      Spree::Deprecation.warn('Store#checkout_zone= is deprecated and will be removed in Spree 5.5. Use Markets instead.')
      super
    end

    # Virtual attribute — sets the country for the default market created on store creation.
    # Not persisted on the store itself; only used by the after_create callback.
    attr_reader :default_country_iso

    def default_country_iso=(iso)
      return if iso.blank?

      @default_country_iso = iso

      country = Spree::Country.by_iso(iso)

      unless country
        iso_country = ::Country[iso]
        return unless iso_country

        country = Spree::Country.create!(
          iso_name: iso_country.local_name&.upcase,
          iso: iso_country.alpha2,
          iso3: iso_country.alpha3,
          name: iso_country.local_name,
          numcode: iso_country.number,
          states_required: Spree::Address::STATES_REQUIRED.include?(iso),
          zipcode_required: !Spree::Address::NO_ZIPCODE_ISO_CODES.include?(iso)
        )
      end

      @default_country_for_market = country
    end

    def unique_name
      @unique_name ||= "#{name} (#{code})"
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
      return Spree::Country.order(:name) if Spree::DeliveryMethod.where(delivery_zone_id: nil).exists?

      zone_ids = Spree::DeliveryMethod.where.not(delivery_zone_id: nil).select(:delivery_zone_id)
      members = Spree::DeliveryZoneMember.where(delivery_zone_id: zone_ids)

      country_ids = members.where(member_type: %w[country postal_code]).select(:country_id)
      state_country_ids = Spree::State.where(id: members.where(member_type: 'state').select(:state_id)).select(:country_id)

      Spree::Country
        .where(id: country_ids)
        .or(Spree::Country.where(id: state_country_ids))
        .order(:name)
    end

    # Returns the default stock location for the store or creates a new one if it doesn't exist
    # @return [Spree::StockLocation]
    def default_stock_location
      @default_stock_location ||= begin
        stock_location_scope = Spree::StockLocation.where(default: true)
        stock_location_scope.first || ActiveRecord::Base.connected_to(role: :writing) do
          stock_location_scope.create(default: true, name: Spree.t(:default_stock_location_name),
                                      country: default_country)
        end
      end
    end

    def metric_unit_system?
      preferred_unit_system == 'metric'
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
  end
end
