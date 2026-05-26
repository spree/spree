module Spree
  class Market < Spree.base_class
    has_prefix_id :mkt

    include Spree::SingleStoreResource

    acts_as_paranoid
    acts_as_list scope: :store_id

    #
    # Associations
    #
    belongs_to :store, class_name: 'Spree::Store', touch: true
    has_many :market_countries, class_name: 'Spree::MarketCountry', dependent: :destroy
    has_many :countries, through: :market_countries, class_name: 'Spree::Country'
    has_many :orders, class_name: 'Spree::Order', dependent: :nullify

    #
    # Validations
    #
    validates :store, presence: true
    validates :name, presence: true, uniqueness: { scope: spree_base_uniqueness_scope + [:store_id] }
    validates :currency, presence: true
    validates :default_locale, presence: true
    validates :countries, presence: true

    #
    # Callbacks
    #
    before_save :ensure_single_default
    before_destroy :ensure_can_be_deleted

    #
    # Scopes
    #
    scope :default, -> { where(default: true) }

    # Find the market that contains the given country for a store
    #
    # @param country [Spree::Country] the country to look up
    # @param store [Spree::Store] the store to scope to
    # @return [Spree::Market, nil]
    def self.for_country(country, store:)
      return nil unless country && store

      joins(:market_countries)
        .where(store_id: store.id)
        .where(spree_market_countries: { country_id: country.id })
        .take
    end

    # Returns the default market for a store, or falls back to the first by position
    #
    # @param store [Spree::Store]
    # @return [Spree::Market, nil]
    def self.default_for_store(store)
      return nil unless store

      store.markets.default.first || store.markets.order(:position).first
    end

    # Returns the first country by name from this market's countries
    #
    # @return [Spree::Country, nil]
    def default_country
      countries.order(:name).first
    end

    # Returns the tax zone matching this market's default country.
    # Used by Spree::Current to determine the browsing tax zone before a customer enters an address.
    #
    # @return [Spree::Zone, nil]
    def tax_zone
      @tax_zone ||= Spree::Zone.match(default_country)
    end

    # Returns supported locales as an array, always including default_locale
    #
    # @return [Array<String>]
    def supported_locales_list
      @supported_locales_list ||= (supported_locales.to_s.split(',').map(&:strip) << default_locale).compact.uniq.sort
    end

    # Accepts an Array of locale codes and persists them as a comma-separated
    # string on the `supported_locales` column. Strings are still accepted
    # verbatim so legacy callers (the Rails admin form, raw seed scripts)
    # keep working.
    #
    # @param value [Array<String>, String, nil]
    def supported_locales=(value)
      @supported_locales_list = nil
      normalized = value.is_a?(Array) ? value.compact.uniq.reject(&:blank?).join(',') : value
      super(normalized)
    end

    # Read companion for `country_isos=`. Returns the sorted list of ISO codes
    # currently assigned to the market.
    #
    # @return [Array<String>]
    def country_isos
      countries.map(&:iso).compact.sort
    end

    # Accepts an Array of 2-letter ISO codes and resolves them to the matching
    # `Spree::Country` records, replacing the market's countries. Unknown codes
    # are silently dropped — the `validates :countries, presence: true` covers
    # the "every ISO was bogus" case.
    #
    # @param values [Array<String>]
    def country_isos=(values)
      isos = Array(values).compact.map { |v| v.to_s.upcase }.reject(&:blank?)
      self.countries = isos.any? ? Spree::Country.where(iso: isos) : []
    end

    # Returns true when the market is safe to delete. A market cannot be deleted
    # if it is the default market or the only market in the store, since
    # Spree::Current.currency would have no fallback.
    #
    # @return [Boolean]
    def can_be_deleted?
      !default? && !last_in_store?
    end

    private

    def last_in_store?
      !self.class.where(store_id: store_id).where.not(id: id).exists?
    end

    def ensure_single_default
      return unless default? && default_changed?

      self.class.where(store_id: store_id, default: true).where.not(id: id).update_all(default: false)
    end

    def ensure_can_be_deleted
      return if can_be_deleted?

      if default?
        errors.add(:base, :cannot_destroy_default_market)
      else
        errors.add(:base, :cannot_destroy_last_market)
      end
      throw(:abort)
    end
  end
end
