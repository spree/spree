require 'uri'

module Spree
  class Store < Spree.base_class
    has_prefix_id :store  # Spree-specific: store

    include FriendlyId
    include Spree::TranslatableResource
    include Spree::Metafields
    include Spree::Metadata
    include Spree::Stores::Setup
    include Spree::Stores::Socials
    include Spree::Stores::Markets
    include Spree::Security::Stores if defined?(Spree::Security::Stores)
    include Spree::UserManagement

    #
    # Magic methods
    #
    acts_as_paranoid
    friendly_id :code, use: [:slugged], slug_column: :code, routes: :normal

    #
    # Translations
    #
    TRANSLATABLE_FIELDS = %i[name meta_description meta_keywords seo_title facebook
                             twitter instagram customer_support_email
                             address contact_phone].freeze
    translates(*TRANSLATABLE_FIELDS, column_fallback: !Spree.always_use_translations?)
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
    preference :unit_system, :string, default: 'imperial'
    # email preferences
    preference :send_consumer_transactional_emails, :boolean, default: true
    # SEO preferences
    preference :index_in_search_engines, :boolean, default: false
    preference :password_protected, :boolean, default: false
    # Checkout preferences
    preference :guest_checkout, :boolean, default: true
    preference :special_instructions_enabled, :boolean, default: false
    # Address preferences
    preference :company_field_enabled, :boolean, default: false
    # digital assets preferences
    preference :limit_digital_download_count, :boolean, default: true
    preference :limit_digital_download_days, :boolean, default: true
    preference :digital_asset_authorized_clicks, :integer, default: 5
    preference :digital_asset_authorized_days, :integer, default: 7
    preference :digital_asset_link_expire_time, :integer, default: 300

    #
    # Associations
    #
    has_many :checkouts, -> { incomplete }, class_name: 'Spree::Order', inverse_of: :store
    has_many :orders, class_name: 'Spree::Order'
    has_many :line_items, through: :orders, class_name: 'Spree::LineItem'
    has_many :digital_links, through: :line_items, class_name: 'Spree::DigitalLink'
    has_many :shipments, through: :orders, class_name: 'Spree::Shipment'
    has_many :payments, through: :orders, class_name: 'Spree::Payment'
    has_many :return_authorizations, through: :orders, class_name: 'Spree::ReturnAuthorization'
    # has_many :reimbursements, through: :orders, class_name: 'Spree::Reimbursement' FIXME: we should fetch this via Customer Return

    has_many :store_payment_methods, class_name: 'Spree::StorePaymentMethod'
    has_many :payment_methods, through: :store_payment_methods, class_name: 'Spree::PaymentMethod'

    has_many :store_products, class_name: 'Spree::StoreProduct'
    has_many :products, through: :store_products, class_name: 'Spree::Product'
    has_many :product_properties, through: :products, class_name: 'Spree::ProductProperty'
    has_many :variants, through: :products, class_name: 'Spree::Variant', source: :variants_including_master
    has_many :stock_items, through: :variants, class_name: 'Spree::StockItem'
    has_many :inventory_units, through: :variants, class_name: 'Spree::InventoryUnit'
    has_many :option_value_variants, through: :variants, class_name: 'Spree::OptionValueVariant'
    has_many :customer_returns, class_name: 'Spree::CustomerReturn', inverse_of: :store

    has_many :store_credits, class_name: 'Spree::StoreCredit'
    has_many :store_credit_events, through: :store_credits, class_name: 'Spree::StoreCreditEvent'

    has_many :taxonomies, class_name: 'Spree::Taxonomy'
    has_many :taxons, through: :taxonomies, class_name: 'Spree::Taxon'

    has_many :store_promotions, class_name: 'Spree::StorePromotion'
    has_many :promotions, through: :store_promotions, class_name: 'Spree::Promotion'

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

    has_many :customer_groups, class_name: 'Spree::CustomerGroup', dependent: :destroy, inverse_of: :store

    has_many :api_keys, class_name: 'Spree::ApiKey', dependent: :destroy


    #
    # ActionText
    #
    has_rich_text :checkout_message
    has_rich_text :customer_terms_of_service
    has_rich_text :customer_privacy_policy
    has_rich_text :customer_returns_policy
    has_rich_text :customer_shipping_policy

    #
    # Virtual attributes
    #
    store_accessor :private_metadata, :storefront_password

    #
    # Validations
    #
    with_options presence: true do
      validates :name, :url, :mail_from_address, :code
    end
    validates :preferred_digital_asset_authorized_clicks, numericality: { only_integer: true, greater_than: 0 }
    validates :preferred_digital_asset_authorized_days, numericality: { only_integer: true, greater_than: 0 }
    validates :mail_from_address, email: { allow_blank: false }
    # FIXME: we should remove this condition in v5
    if !ENV['SPREE_DISABLE_DB_CONNECTION'] &&
        connected? &&
        table_exists? &&
        connection.column_exists?(:spree_stores, :new_order_notifications_email)
      validates :new_order_notifications_email, email: { allow_blank: true }
    end
    validates :favicon_image, :social_image, :mailer_logo, content_type: Rails.application.config.active_storage.web_image_content_types

    #
    # Attachments
    #
    has_one_attached :logo, service: Spree.public_storage_service_name
    has_one_attached :favicon_image, service: Spree.public_storage_service_name
    has_one_attached :social_image, service: Spree.public_storage_service_name
    has_one_attached :mailer_logo, service: Spree.public_storage_service_name

    #
    # Callbacks
    before_validation :set_default_code, on: :create
    before_save :ensure_default_exists_and_is_unique
    after_create :ensure_default_market
    after_create :ensure_default_taxonomies_are_created
    after_create :ensure_default_automatic_taxons
    after_create :create_default_policies

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

    # @deprecated The or_initialize behavior will be removed in Spree 5.5.
    def self.default
      # workaround for Mobility bug with first_or_initialize
      if where(default: true).any?
        where(default: true).first
      else
        Spree::Deprecation.warn(
          'Spree::Store.default returning a new unpersisted store when no default store exists is deprecated ' \
          'and will be removed in Spree 5.5. Please ensure a default store is created before calling Store.default.'
        )
        new(default: true)
      end
    end

    def self.available_locales
      Spree::Store.default&.supported_locales_list || []
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

    def seo_meta_description
      if meta_description.present?
        meta_description
      elsif seo_title.present?
        seo_title
      else
        name
      end
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

    # Returns the states available for checkout for the store
    # @param country [Spree::Country] the country to get the states for
    # @return [Array<Spree::State>]
    def states_available_for_checkout(country)
      country.states.to_a
    end

    # @deprecated Use {Spree::Zone.all} or {#countries_with_shipping_coverage} instead.
    #   Will be removed in Spree 5.5.
    def supported_shipping_zones
      Spree::Deprecation.warn(
        'Store#supported_shipping_zones is deprecated and will be removed in Spree 5.5. ' \
        'Use Spree::Zone.all or Store#countries_with_shipping_coverage instead.'
      )
      zone = Spree::Zone.find_by(id: read_attribute(:checkout_zone_id))
      if zone.present?
        [zone]
      else
        Spree::Zone.includes(zone_members: :zoneable).all
      end
    end

    # Returns countries covered by at least one shipping zone
    # that has an active shipping method attached.
    # Handles both country-type zones (direct membership) and
    # state-type zones (country inferred from state).
    #
    # @return [ActiveRecord::Relation<Spree::Country>]
    def countries_with_shipping_coverage
      zone_ids = Spree::Zone
        .joins(:shipping_methods)
        .select(:id)

      country_zone_country_ids = Spree::ZoneMember
        .where(zone_id: zone_ids, zoneable_type: 'Spree::Country')
        .select(:zoneable_id)

      state_zone_country_ids = Spree::State
        .where(id: Spree::ZoneMember
          .where(zone_id: zone_ids, zoneable_type: 'Spree::State')
          .select(:zoneable_id))
        .select(:country_id)

      Spree::Country
        .where(id: country_zone_country_ids)
        .or(Spree::Country.where(id: state_zone_country_ids))
        .order(:name)
    end

    # Returns the default stock location for the store or creates a new one if it doesn't exist
    # @return [Spree::StockLocation]
    def default_stock_location
      @default_stock_location ||= begin
        stock_location_scope = Spree::StockLocation.where(default: true)
        stock_location_scope.first || ActiveRecord::Base.connected_to(role: :writing) do
          stock_location_scope.create(default: true, name: Spree.t(:default_stock_location_name), country: default_country)
        end
      end
    end

    def admin_users
      Spree::Deprecation.warn('Store#admin_users is deprecated and will be removed in Spree 5.5. Please use Store#users instead.')

      users
    end

    def favicon
      return unless favicon_image.attached? && favicon_image.variable?

      favicon_image.variant(resize_to_limit: [32, 32])
    end

    def metric_unit_system?
      preferred_unit_system == 'metric'
    end

    def default_shipping_category
      @default_shipping_category ||= ShippingCategory.find_or_create_by(name: 'Default')
    end

    def digital_shipping_category
      @digital_shipping_category ||= ShippingCategory.find_or_create_by(name: 'Digital')
    end

    %w[customer_terms_of_service customer_privacy_policy customer_returns_policy customer_shipping_policy].each do |policy_method|
      define_method policy_method do
        Spree::Deprecation.warn("Store##{policy_method} is deprecated and will be removed in Spree 5.5. Please use Store#policies instead.")

        ActionText::RichText.find_by(name: policy_method, record: self)
      end
    end

    private

    def ensure_default_market
      return if markets.exists?

      country = @default_country_for_market
      return if country.blank?

      iso_country = ISO3166::Country[country.iso]

      Spree::Events.disable do
        markets.create!(
          name: country.name,
          currency: iso_country&.currency_code || read_attribute(:default_currency) || 'USD',
          default_locale: iso_country&.languages_official&.first || read_attribute(:default_locale) || 'en',
          default: true,
          countries: [country]
        )
      end
    end

    def ensure_default_taxonomies_are_created
      Spree::Events.disable do
        [
          translate_with_store_locale_fallback('spree.taxonomy_categories_name'),
          translate_with_store_locale_fallback('spree.taxonomy_brands_name'),
          translate_with_store_locale_fallback('spree.taxonomy_collections_name')
        ].each do |taxonomy_name|
          # Manual exists?/create to work around Mobility bug with find_or_create_by
          next if taxonomies.with_matching_name(taxonomy_name).exists?

          taxonomies.create(name: taxonomy_name)
        end
      end
    end

    def ensure_default_automatic_taxons
      Spree::Events.disable do
        # Use Mobility-safe lookup for taxonomy
        collections_taxonomy = taxonomies.with_matching_name(translate_with_store_locale_fallback('spree.taxonomy_collections_name')).first
        return unless collections_taxonomy.present?

        automatic_taxons_config = [
          { name: translate_with_store_locale_fallback('spree.automatic_taxon_names.on_sale'), rule_type: 'Spree::TaxonRules::Sale', rule_value: 'true' },
          { name: translate_with_store_locale_fallback('spree.automatic_taxon_names.new_arrivals'), rule_type: 'Spree::TaxonRules::AvailableOn', rule_value: 30 }
        ]

        automatic_taxons_config.map do |config|
          # Manual exists?/create to work around Mobility bug with first_or_create
          taxon_scope = collections_taxonomy.taxons.automatic.with_matching_name(config[:name])

          if taxon_scope.exists?
            taxon_scope.first
          else
            collections_taxonomy.taxons.create!(
              name: config[:name],
              automatic: true,
              parent: collections_taxonomy.root,
              taxon_rules: [TaxonRule.new(type: config[:rule_type], value: config[:rule_value])]
            )
          end
        end
      end
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

    def set_default_code
      self.code = 'default' if code.blank?
    end
  end
end
