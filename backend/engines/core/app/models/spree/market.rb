module Spree
  class Market < Spree.base_class
    has_prefix_id :mkt

    include Spree::SingleStoreResource

    acts_as_paranoid
    acts_as_list scope: :store_id

    #
    # Associations
    #
    belongs_to :store, class_name: 'Spree::Store'
    has_many :market_countries, class_name: 'Spree::MarketCountry', dependent: :destroy
    has_many :countries, through: :market_countries, class_name: 'Spree::Country'

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
        .order(:position)
        .first
    end

    # Returns the default market for a store, or falls back to the first by position
    #
    # @param store [Spree::Store]
    # @return [Spree::Market, nil]
    def self.default_for_store(store)
      return nil unless store

      store.markets.default.first || store.markets.order(:position).first
    end

    # Returns supported locales as an array, always including default_locale
    #
    # @return [Array<String>]
    def supported_locales_list
      @supported_locales_list ||= (supported_locales.to_s.split(',').map(&:strip) << default_locale).compact.uniq.sort
    end

    private

    def ensure_single_default
      return unless default? && default_changed?

      self.class.where(store_id: store_id, default: true).where.not(id: id).update_all(default: false)
    end
  end
end
