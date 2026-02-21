module Spree
  class MarketCountry < Spree.base_class
    self.table_name = 'spree_market_countries'

    belongs_to :market, class_name: 'Spree::Market'
    belongs_to :country, class_name: 'Spree::Country'

    validates :market, :country, presence: true
    validates :country_id, uniqueness: { scope: :market_id }
    validate :country_covered_by_shipping_zone

    private

    def country_covered_by_shipping_zone
      return if market.blank? || country.blank?

      store = market.store
      return if store.blank?

      unless store.countries_with_shipping_coverage.exists?(id: country.id)
        errors.add(:country, :not_in_shipping_zone)
      end
    end
  end
end
