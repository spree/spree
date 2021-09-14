module Spree
  class Store < Spree::Base
    MAILER_LOGO_CONTENT_TYPES = ['image/png', 'image/jpg', 'image/jpeg'].freeze
    FAVICON_CONTENT_TYPES = ['image/png', 'image/x-icon', 'image/vnd.microsoft.icon'].freeze

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
    has_many :customer_returns, class_name: 'Spree::CustomerReturn', inverse_of: :store

    has_many :store_credits, class_name: 'Spree::StoreCredit'
    has_many :store_credit_events, through: :store_credits, class_name: 'Spree::StoreCreditEvent'

    has_many :taxonomies, class_name: 'Spree::Taxonomy'
    has_many :taxons, through: :taxonomies, class_name: 'Spree::Taxon'

    has_many :store_promotions, class_name: 'Spree::StorePromotion'
    has_many :promotions, through: :store_promotions, class_name: 'Spree::Promotion'

    belongs_to :default_country, class_name: 'Spree::Country'
    belongs_to :checkout_zone, class_name: 'Spree::Zone'

    with_options presence: true do
      validates :name, :url, :mail_from_address, :default_currency, :code
    end

    validates :code, uniqueness: true

    if !ENV['SPREE_DISABLE_DB_CONNECTION'] &&
        connected? &&
        table_exists? &&
        connection.column_exists?(:spree_stores, :new_order_notifications_email)
      validates :new_order_notifications_email, email: { allow_blank: true }
    end

    default_scope { order(created_at: :asc) }

    has_one_attached :logo
    has_one_attached :mailer_logo
    has_one_attached :favicon_image

    validates :mailer_logo, content_type: MAILER_LOGO_CONTENT_TYPES
    validates :favicon_image, content_type: FAVICON_CONTENT_TYPES,
                              dimension: { max: 256..256 },
                              aspect_ratio: :square,
                              size: { less_than_or_equal_to: 1.megabyte }

    before_save :ensure_default_exists_and_is_unique
    before_save :ensure_supported_currencies, :ensure_supported_locales, :ensure_default_country
    before_destroy :validate_not_default

    scope :by_url, ->(url) { where('url like ?', "%#{url}%") }

    after_commit :clear_cache

    alias_attribute :contact_email, :customer_support_email

    def self.current(url = nil)
      ActiveSupport::Deprecation.warn(<<-DEPRECATION, caller)
        `Spree::Store.current` is deprecated and will be removed in Spree 5.0
        Please use `Spree::Stores::FindCurrent.new(url: "https://example.com").execute` instead
      DEPRECATION
      Stores::FindCurrent.new(url: url).execute
    end

    def self.default
      Rails.cache.fetch('default_store') do
        where(default: true).first_or_initialize
      end
    end

    def self.available_locales
      Rails.cache.fetch('stores_available_locales') do
        Spree::Store.all.map(&:supported_locales_list).flatten.uniq
      end
    end

    def default_menu(location)
      menu = menus.find_by(location: location, locale: default_locale) || menus.find_by(location: location)

      menu.root if menu.present?
    end

    def supported_currencies_list
      @supported_currencies_list ||= (read_attribute(:supported_currencies).to_s.split(',') << default_currency).sort.map(&:to_s).map do |code|
        ::Money::Currency.find(code.strip)
      end.uniq.compact
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
      @countries_available_for_checkout ||= checkout_zone_or_default.try(:country_list) || Spree::Country.all
    end

    def states_available_for_checkout(country)
      checkout_zone_or_default.try(:state_list_for, country) || country.states
    end

    def checkout_zone_or_default
      @checkout_zone_or_default ||= checkout_zone || Spree::Zone.default_checkout_zone
    end

    def favicon
      return unless favicon_image.attached?

      favicon_image.variant(resize: '32x32')
    end

    private

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

    def validate_not_default
      if default
        errors.add(:base, :cannot_destroy_default_store)
        throw(:abort)
      end
    end

    def clear_cache
      Rails.cache.delete('default_store')
      Rails.cache.delete('stores_available_locales')
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
  end
end
