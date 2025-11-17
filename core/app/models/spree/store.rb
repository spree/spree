require 'uri'

module Spree
  class Store < Spree.base_class
    RESERVED_CODES = %w(
      admin default app api www cdn files assets checkout account auth login user
    )

    include FriendlyId
    include Spree::TranslatableResource
    include Spree::Metafields
    include Spree::Metadata
    include Spree::Stores::Setup
    include Spree::Stores::Socials
    include Spree::Webhooks::HasWebhooks if defined?(Spree::Webhooks::HasWebhooks)
    include Spree::Security::Stores if defined?(Spree::Security::Stores)
    include Spree::UserManagement
    include Spree::HasPageLinks

    #
    # Magic methods
    #
    acts_as_paranoid
    friendly_id :slug_candidates, use: [:slugged, :history], slug_column: :code, routes: :normal

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

    has_many :custom_domains, class_name: 'Spree::CustomDomain', dependent: :destroy
    has_one :default_custom_domain, -> { where(default: true) }, class_name: 'Spree::CustomDomain'

    has_many :posts, class_name: 'Spree::Post', dependent: :destroy, inverse_of: :store
    has_many :post_categories, class_name: 'Spree::PostCategory', dependent: :destroy, inverse_of: :store

    has_many :integrations, class_name: 'Spree::Integration'

    has_many :gift_cards, class_name: 'Spree::GiftCard', dependent: :destroy

    has_many :policies, class_name: 'Spree::Policy', dependent: :destroy, as: :owner

    #
    # Page Builder associations
    #
    has_many :themes, -> { without_previews }, class_name: 'Spree::Theme', dependent: :destroy, inverse_of: :store
    has_many :theme_previews,
             -> { only_previews },
             class_name: 'Spree::Theme',
             through: :themes,
             source: :previews,
             inverse_of: :store,
             dependent: :destroy
    has_one :default_theme, -> { without_previews.where(default: true) }, class_name: 'Spree::Theme', inverse_of: :store
    alias theme default_theme
    has_many :theme_pages, class_name: 'Spree::Page', through: :themes, source: :pages
    has_many :theme_page_previews, class_name: 'Spree::Page', through: :theme_pages, source: :previews
    has_many :pages, -> { without_previews.custom }, class_name: 'Spree::Pages::Custom', dependent: :destroy, as: :pageable
    has_many :page_previews, class_name: 'Spree::Pages::Custom', through: :pages, as: :pageable, source: :previews

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
    attribute :import_products_from_store_id, :string, default: nil
    attribute :import_payment_methods_from_store_id, :string, default: nil
    attr_accessor :skip_validate_not_last
    store_accessor :private_metadata, :storefront_password

    #
    # Validations
    #
    with_options presence: true do
      validates :name, :url, :mail_from_address, :default_currency, :default_country, :code
    end
    validates :preferred_digital_asset_authorized_clicks, numericality: { only_integer: true, greater_than: 0 }
    validates :preferred_digital_asset_authorized_days, numericality: { only_integer: true, greater_than: 0 }
    validates :code, uniqueness: { case_sensitive: false, conditions: -> { with_deleted } }, exclusion: RESERVED_CODES
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
    before_validation :ensure_default_country
    before_validation :set_code, on: :create
    before_validation :set_url
    before_save :ensure_default_exists_and_is_unique
    before_save :ensure_supported_currencies, :ensure_supported_locales
    after_create :ensure_default_taxonomies_are_created
    after_create :ensure_default_automatic_taxons
    after_create :ensure_default_post_categories_are_created
    after_create :import_products_from_store, if: -> { import_products_from_store_id.present? }
    after_create :import_payment_methods_from_store, if: -> { import_payment_methods_from_store_id.present? }
    after_create :create_default_theme
    after_create :create_default_policies
    before_destroy :validate_not_last, unless: :skip_validate_not_last
    before_destroy :pass_default_flag_to_other_store
    after_commit :clear_cache
    after_commit :handle_code_changes, on: :update, if: -> { code_previously_changed? }

    #
    # Scopes
    #
    default_scope { order(created_at: :asc) }
    scope :by_custom_domain, ->(url) { left_joins(:custom_domains).where("#{Spree::CustomDomain.table_name}.url" => url) }
    scope :by_url, ->(url) { where(url: url).or(where("#{table_name}.url like ?", "%#{url}%")) }

    #
    # Delegations
    #
    delegate :iso, to: :default_country, prefix: true, allow_nil: true

    def self.current(url = nil)
      if url.present?
        Spree::Dependencies.current_store_finder.constantize.new(url: url).execute
      else
        Spree::Current.store
      end
    end

    # FIXME: we need to drop `or_initialize` in v5
    # this behaviour is very buggy and unpredictable
    def self.default
      Rails.cache.fetch('default_store') do
        # workaround for Mobility bug with first_or_initialize
        if where(default: true).any?
          where(default: true).first
        else
          new(default: true)
        end
      end
    end

    def self.available_locales
      Spree::Store.all.map(&:supported_locales_list).flatten.uniq
    end

    def default_country_iso=(iso)
      return if iso.blank?

      @default_country_iso = iso

      country = Spree::Country.by_iso(iso)

      if country.present?
        self.default_country = country
      elsif iso_country = ::Country[iso]
        new_country = Spree::Country.create!(
          iso_name: iso_country.local_name&.upcase,
          iso: iso_country.alpha2,
          iso3: iso_country.alpha3,
          name: iso_country.local_name,
          numcode: iso_country.number,
          states_required: Spree::Address::STATES_REQUIRED.include?(iso),
          zipcode_required: !Spree::Address::NO_ZIPCODE_ISO_CODES.include?(iso)
        )

        self.default_country = new_country
      end
    end

    def supported_currencies_list
      @supported_currencies_list ||= ([default_currency] + read_attribute(:supported_currencies).to_s.split(',')).uniq.map(&:to_s).map do |code|
        ::Money::Currency.find(code.strip)
      end.compact.sort_by { |currency| currency.iso_code == default_currency ? 0 : 1 }
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

    def supported_locales_list
      @supported_locales_list ||= (read_attribute(:supported_locales).to_s.split(',') << default_locale).compact.uniq.sort
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

    def formatted_custom_domain
      return unless default_custom_domain

      @formatted_custom_domain ||= if Rails.env.development? || Rails.env.test?
        URI::Generic.build(
          scheme: Rails.application.routes.default_url_options[:protocol] || 'http',
          host: default_custom_domain.url,
          port: Rails.application.routes.default_url_options[:port]
        ).to_s
      else
        URI::HTTPS.build(host: default_custom_domain.url).to_s
      end
    end

    def url_or_custom_domain
      default_custom_domain&.url || url
    end

    def formatted_url_or_custom_domain
      formatted_custom_domain || formatted_url
    end

    # Returns the countries available for checkout for the store or creates a new one if it doesn't exist
    # @return [Array<Spree::Country>]
    def countries_available_for_checkout
      @countries_available_for_checkout ||= Rails.cache.fetch(countries_available_for_checkout_cache_key) do
        (checkout_zone.try(:country_list) || Spree::Country.all).to_a
      end
    end

    # Returns the states available for checkout for the store or creates a new one if it doesn't exist
    # @param country [Spree::Country] the country to get the states for
    # @return [Array<Spree::State>]
    def states_available_for_checkout(country)
      Rails.cache.fetch(states_available_for_checkout_cache_key(country)) do
        (checkout_zone.try(:state_list_for, country) || country.states).to_a
      end
    end

    def checkout_zone_or_default
      Spree::Deprecation.warn('Store#checkout_zone_or_default is deprecated and will be removed in Spree 5')

      @checkout_zone_or_default ||= checkout_zone || Spree::Zone.default_checkout_zone
    end

    def supported_shipping_zones
      @supported_shipping_zones ||= if checkout_zone.present?
                                      [checkout_zone]
                                    else
                                      Spree::Zone.includes(zone_members: :zoneable).all
                                    end
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
      Spree::Deprecation.warn('Store#admin_users is deprecated and will be removed in Spree 6.0. Please use Store#users instead.')

      users
    end

    def favicon
      return unless favicon_image.attached? && favicon_image.variable?

      favicon_image.variant(resize_to_limit: [32, 32])
    end

    def can_be_deleted?
      self.class.where.not(id: id).any?
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

    def import_products_from_store
      store = Store.find(import_products_from_store_id)
      product_ids = store.products.pluck(:id)

      return if product_ids.empty?

      StoreProduct.insert_all(product_ids.map { |product_id| { store_id: id, product_id: product_id } })
    end

    def import_payment_methods_from_store
      store = Store.find(import_payment_methods_from_store_id)
      payment_method_ids = store.payment_method_ids

      return if payment_method_ids.empty?

      StorePaymentMethod.insert_all(payment_method_ids.map { |payment_method_id| { store_id: id, payment_method_id: payment_method_id } })
    end

    %w[customer_terms_of_service customer_privacy_policy customer_returns_policy customer_shipping_policy].each do |policy_method|
      define_method policy_method do
        Spree::Deprecation.warn("Store##{policy_method} is deprecated and will be removed in Spree 6.0. Please use Store#policies instead.")

        ActionText::RichText.find_by(name: policy_method, record: self)
      end
    end

    # Returns all active webhooks subscribers for the store
    #
    # @return [Array<Spree::Webhooks::Subscriber>]
    def active_webhooks_subscribers
      @active_webhooks_subscribers ||= Spree::Webhooks::Subscriber.active
    end

    private

    def countries_available_for_checkout_cache_key
      "#{cache_key_with_version}/#{checkout_zone&.cache_key_with_version}/countries_available_for_checkout"
    end

    def states_available_for_checkout_cache_key(country)
      "#{cache_key_with_version}/#{checkout_zone&.cache_key_with_version}/states_available_for_checkout/#{country&.cache_key_with_version}"
    end

    def ensure_default_exists_and_is_unique
      if default
        Store.where.not(id: id).update_all(default: false)
      elsif Store.where(default: true).count.zero?
        self.default = true
      end
    end

    def ensure_supported_locales
      return unless attributes.keys.include?('supported_locales')
      return if supported_locales.present?
      return if default_locale.blank?

      self.supported_locales = default_locale
    end

    def ensure_supported_currencies
      return unless attributes.keys.include?('supported_currencies')
      return if supported_currencies.present?
      return if default_currency.blank?

      self.supported_currencies = default_currency
    end

    def validate_not_last
      unless can_be_deleted?
        errors.add(:base, :cannot_destroy_only_store)
        throw(:abort)
      end
    end

    def pass_default_flag_to_other_store
      if default? && can_be_deleted?
        self.class.where.not(id: id).first.update!(default: true)
        self.default = false
      end
    end

    def clear_cache
      Rails.cache.delete('default_store')
    end

    def ensure_default_country
      return if default_country.present? && (checkout_zone.blank? || checkout_zone.country_list.blank? || checkout_zone.country_list.include?(default_country))

      self.default_country = if checkout_zone.present? && checkout_zone.country_list.any?
                               checkout_zone.country_list.first
                             else
                               Country.find_by(iso: 'US') || Country.first
                             end
    end

    def ensure_default_taxonomies_are_created
      taxonomies.find_or_create_by(name: I18n.t('spree.taxonomy_categories_name', default: I18n.t('spree.taxonomy_categories_name', locale: :en)))
      taxonomies.find_or_create_by(name: I18n.t('spree.taxonomy_brands_name', default: I18n.t('spree.taxonomy_brands_name', locale: :en)))
      taxonomies.find_or_create_by(name: I18n.t('spree.taxonomy_collections_name', default: I18n.t('spree.taxonomy_collections_name', locale: :en)))
    rescue ActiveRecord::NotNullViolation
    end

    def ensure_default_automatic_taxons
      collections_taxonomy = taxonomies.find_by(name: Spree.t(:taxonomy_collections_name))

      if collections_taxonomy.present?
        on_sale_taxon = collections_taxonomy.taxons.automatic.where(name: Spree.t('automatic_taxon_names.on_sale')).first_or_create! do |taxon|
          taxon.parent = collections_taxonomy.root
          taxon.rules.new(type: 'Spree::TaxonRules::Sale', value: 'true')
        end

        new_arrivals_taxon = collections_taxonomy.taxons.automatic.where(name: Spree.t('automatic_taxon_names.new_arrivals')).first_or_create! do |taxon|
          taxon.parent = collections_taxonomy.root
          taxon.rules.new(type: 'Spree::TaxonRules::AvailableOn', value: 30)
        end

        [on_sale_taxon, new_arrivals_taxon]
      end
    end

    def ensure_default_post_categories_are_created
      post_categories.find_or_create_by(title: Spree.t('default_post_categories.resources'))
      post_categories.find_or_create_by(title: Spree.t('default_post_categories.articles'))
      post_categories.find_or_create_by(title: Spree.t('default_post_categories.news'))
    end

    def create_default_policies
      policies.find_or_create_by(name: Spree.t('terms_of_service'))
      policies.find_or_create_by(name: Spree.t('privacy_policy'))
      policies.find_or_create_by(name: Spree.t('returns_policy'))
      policies.find_or_create_by(name: Spree.t('shipping_policy'))

      # Create checkout links to the policies
      policies.each do |policy|
        links.find_or_create_by(linkable: policy)
      end
    end

    # code is slug, so we don't want to generate new slug when code changes
    # we use friendlyId only for history feature
    def should_generate_new_friendly_id?
      false
    end

    def slug_candidates
      []
    end

    def handle_code_changes
      # implement your custom logic here
    end

    # This FriendlyId method is overwitten to keep our logic for generating code
    # there is no option for own format
    def set_code
      self.code = if code.present?
                    code.parameterize.strip
                  elsif name.present?
                    name.parameterize.strip
                  end

      return if self.code.blank?

      # ensure code is unique
      self.code = [name.parameterize, rand(9999)].join('-') while Spree::Store.with_deleted.where(code: self.code).exists?
    end

    # auto-assign internal URL for stores
    def set_url
      return if url_changed?
      return unless code_changed?
      return unless Spree.root_domain.present?

      self.url = [code, Spree.root_domain].join('.')
    end

    def create_default_theme
      themes.find_or_initialize_by(default: true) do |theme|
        theme.name = Spree.t(:default_theme_name)
        theme.save!
      end
    end
  end
end
