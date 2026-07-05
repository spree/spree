module Spree
  class MarketCountry < Spree.base_class
    self.table_name = 'spree_market_countries'

    belongs_to :market, class_name: 'Spree::Market'
    belongs_to :country, class_name: 'Spree::Country'

    validates :market, :country, presence: true
    validates :country_id, uniqueness: { scope: :market_id }
    validate :country_covered_by_shipping_zone
    validate :country_unique_per_store

    private

    def country_covered_by_shipping_zone
      return if market.blank? || country.blank?

      store = market.store
      return if store.blank?

      unless store.countries_with_shipping_coverage.exists?(id: country.id)
        errors.add(:country, :not_in_shipping_zone)
      end
    end

    def country_unique_per_store
      return if market.blank? || country.blank?

      store = market.store
      return if store.blank?

      existing = self.class.joins(:market)
                     .where(country_id: country_id)
                     .where(spree_markets: { store_id: store.id, deleted_at: nil })
                     .where.not(id: id)

      if existing.exists?
        errors.add(:country, :already_in_market)
      end
    end
  end
end
