module Spree
  class Store < Spree.base_class
    include Spree::TranslatableResource
    if defined?(Spree::Webhooks::HasWebhooks)
      include Spree::Webhooks::HasWebhooks
    end
    if defined?(Spree::Security::Stores)
      include Spree::Security::Stores
    end

    TRANSLATABLE_FIELDS = %i[name meta_description meta_keywords seo_title facebook
                             twitter instagram customer_support_email description
                             address contact_phone new_order_notifications_email].freeze
    translates(*TRANSLATABLE_FIELDS, column_fallback: !Spree.always_use_translations?)

    self::Translation.class_eval do
      acts_as_paranoid
      # deleted translation values still need to be accessible - remove deleted_at scope
      default_scope { unscope(where: :deleted_at) }
    end

    typed_store :settings, coder: ActiveRecord::TypedStore::IdentityCoder do |s|
      # Spree Digital Asset Configurations
      s.boolean :limit_digital_download_count, default: true, null: false
      s.boolean :limit_digital_download_days, default: true, null: false
      s.integer :digital_asset_authorized_clicks, default: 5, null: false # number of times a customer can download a digital file.
      s.integer :digital_asset_authorized_days, default: 7, null: false # number of days after initial purchase the customer can download a file.
      s.integer :digital_asset_link_expire_time, default: 300, null: false # 5 minutes in seconds

      # store configuration
      s.string :timezone, default: Time.zone.name, null: false
      s.string :weight_unit, default: 'kg', null: false
      s.string :unit_system, default: 'metric', null: false
    end

    attr_accessor :skip_validate_not_last

    acts_as_paranoid

    has_many :orders, class_name: 'Spree::Order'
    has_many :line_items, through: :orders, class_name: 'Spree::LineItem'
    has_many :shipments, through: :orders, class_name: 'Spree::Shipment'
    has_many :payments, through: :orders, class_name: 'Spree::Payment'
    has_many :return_authorizations, through: :orders, class_name: 'Spree::ReturnAuthorization'
    # has_many :reimbursements, through: :orders, class_name: 'Spree::Reimbursement' FIXME: we should fetch this via Customer Return

    has_many :store_payment_methods, class_name: 'Spree::StorePaymentMethod'
    has_many :payment_methods, through: :store_payment_methods, class_name: 'Spree::PaymentMethod'

    has_many :cms_pages, class_name: 'Spree::CmsPage'
    has_many :cms_sections, through: :cms_pages, class_name: 'Spree::CmsSection'

    has_many :menus, class_name: 'Spree::Menu'
    has_many :menu_items, through: :menus, class_name: 'Spree::MenuItem'

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

    has_many :channels, class_name: 'Spree::StoreChannel'

    has_many :taxonomies, class_name: 'Spree::Taxonomy'
    has_many :taxons, through: :taxonomies, class_name: 'Spree::Taxon'

    has_many :store_promotions, class_name: 'Spree::StorePromotion'
    has_many :promotions, through: :store_promotions, class_name: 'Spree::Promotion'

    has_many :wishlists, class_name: 'Spree::Wishlist'

    has_many :data_feeds, class_name: 'Spree::DataFeed'

    belongs_to :default_country, class_name: 'Spree::Country'
    belongs_to :checkout_zone, class_name: 'Spree::Zone'

    #
    # ActionText
    #
    has_rich_text :checkout_message
    has_rich_text :customer_terms_of_service
    has_rich_text :customer_privacy_policy
    has_rich_text :customer_returns_policy
    has_rich_text :customer_shipping_policy

    with_options presence: true do
      validates :name, :url, :mail_from_address, :default_currency, :default_country, :code
    end

    validates :digital_asset_authorized_clicks, numericality: { only_integer: true, greater_than: 0 }
    validates :digital_asset_authorized_days, numericality: { only_integer: true, greater_than: 0 }
    validates :code, uniqueness: { case_sensitive: false, conditions: -> { with_deleted } }
    validates :mail_from_address, email: { allow_blank: false }

    # FIXME: we should remove this condition in v5
    if !ENV['SPREE_DISABLE_DB_CONNECTION'] &&
        connected? &&
        table_exists? &&
        connection.column_exists?(:spree_stores, :new_order_notifications_email)
      validates :new_order_notifications_email, email: { allow_blank: true }
    end

    default_scope { order(created_at: :asc) }

    has_one :logo, class_name: 'Spree::StoreLogo', dependent: :destroy, as: :viewable
    accepts_nested_attributes_for :logo, reject_if: :all_blank

    has_one :mailer_logo, class_name: 'Spree::StoreMailerLogo', dependent: :destroy, as: :viewable
    accepts_nested_attributes_for :mailer_logo, reject_if: :all_blank

    has_one :favicon_image, class_name: 'Spree::StoreFaviconImage', dependent: :destroy, as: :viewable
    accepts_nested_attributes_for :favicon_image, reject_if: :all_blank

    before_validation :ensure_default_country
    before_save :ensure_default_exists_and_is_unique
    before_save :ensure_supported_currencies, :ensure_supported_locales
    after_create :ensure_default_taxonomies_are_created
    after_create :ensure_default_automatic_taxons
    before_destroy :validate_not_last, unless: :skip_validate_not_last
    before_destroy :pass_default_flag_to_other_store

    scope :by_url, ->(url) { where('url like ?', "%#{url}%") }

    after_commit :clear_cache

    delegate :iso, to: :default_country, prefix: true, allow_nil: true

    def self.current(url = nil)
      Spree::Dependencies.current_store_finder.constantize.new(url: url).execute
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

    def default_menu(location)
      menu = menus.find_by(location: location, locale: default_locale) || menus.find_by(location: location)

      menu.root if menu.present?
    end

    def supported_currencies_list
      @supported_currencies_list ||= (read_attribute(:supported_currencies).to_s.split(',') << default_currency).map(&:to_s).map do |code|
        ::Money::Currency.find(code.strip)
      end.uniq.compact.sort_by { |currency| currency.iso_code == default_currency ? 0 : 1 }
    end

    def homepage(requested_locale)
      cms_pages.by_locale(requested_locale).find_by(type: 'Spree::Cms::Pages::Homepage') ||
        cms_pages.by_locale(default_locale).find_by(type: 'Spree::Cms::Pages::Homepage') ||
        cms_pages.find_by(type: 'Spree::Cms::Pages::Homepage')
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
      # TODO: add support of multiple supported languages to a single Store
      @supported_locales_list ||= (read_attribute(:supported_locales).to_s.split(',') << default_locale).compact.uniq.sort
    end

    def unique_name
      @unique_name ||= "#{name} (#{code})"
    end

    def formatted_url
      return if url.blank?

      @formatted_url ||= if url.match(/http:\/\/|https:\/\//)
                           url
                         else
                           Rails.env.development? || Rails.env.test? ? "http://#{url}" : "https://#{url}"
                         end
    end

    def countries_available_for_checkout
      @countries_available_for_checkout ||= Rails.cache.fetch(countries_available_for_checkout_cache_key) do
        checkout_zone.try(:country_list) || Spree::Country.all
      end
    end

    def states_available_for_checkout(country)
      Rails.cache.fetch(states_available_for_checkout_cache_key(country)) do
        checkout_zone.try(:state_list_for, country) || country.states
      end
    end

    def checkout_zone_or_default
      Spree::Deprecation.warn('Store#checkout_zone_or_default is deprecated and will be removed in Spree 5')

      @checkout_zone_or_default ||= checkout_zone || Spree::Zone.default_checkout_zone
    end

    def supported_shipping_zones
      @supported_shipping_zones ||= if checkout_zone_id.present?
                                      [checkout_zone]
                                    else
                                      Spree::Zone.includes(zone_members: :zoneable).all
                                    end
    end

    def default_stock_location
      @default_stock_location ||= begin
        stock_location_scope = Spree::StockLocation.order_default
        stock_location_scope.first || stock_location_scope.create(default: true, name: Spree.t(:default_stock_location_name), country: default_country)
      end
    end

    def favicon
      return unless favicon_image&.attachment&.attached?

      favicon_image.attachment.variant(resize_to_limit: [32, 32])
    end

    def can_be_deleted?
      self.class.where.not(id: id).any?
    end

    def metric_unit_system?
      unit_system == 'metric'
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
      return unless has_attribute?(:default_country_id)
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
  end
end
