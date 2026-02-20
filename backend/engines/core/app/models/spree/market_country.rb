module Spree
  class MarketCountry < Spree.base_class
    self.table_name = 'spree_market_countries'

    belongs_to :market, class_name: 'Spree::Market'
    belongs_to :country, class_name: 'Spree::Country'

    validates :market, :country, presence: true
    validates :country_id, uniqueness: { scope: :market_id }
  end
end
