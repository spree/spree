module Spree
  class MarketCountry < Spree.base_class
    self.table_name = 'spree_market_countries'

    belongs_to :market, class_name: 'Spree::Market'

    # Countries are reference data, so the row stores a code and reads the
    # object back through the registry.
    def country
      Spree::Country.by_iso(country_iso) if country_iso.present?
    end

    def country=(value)
      self.country_iso = value&.iso
    end

    validates :market, presence: true
    validates :country_iso, presence: true
    validates :country_iso, uniqueness: { scope: :market_id }
    validate :country_covered_by_shipping_zone
    validate :country_unique_per_store

    private

    def country_covered_by_shipping_zone
      return if market.blank? || country.blank?

      store = market.store
      return if store.blank?
      # Bootstrap: a store gets its default market during its own creation —
      # no delivery setup can constrain coverage for it yet.
      return if market.bootstrap_default
      return if Spree::DeliveryMethod.none?

      unless store.countries_with_shipping_coverage.exists?(iso: country_iso)
        errors.add(:country, :not_in_shipping_zone)
      end
    end

    def country_unique_per_store
      return if market.blank? || country.blank?

      store = market.store
      return if store.blank?

      existing = self.class.joins(:market)
                     .where(country_iso: country_iso)
                     .where(spree_markets: { store_id: store.id, deleted_at: nil })
                     .where.not(id: id)

      if existing.exists?
        errors.add(:country, :already_in_market)
      end
    end
  end
end
