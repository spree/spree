module Spree
  class StockItem < ActiveRecord::Base
    belongs_to :stock_location
    belongs_to :variant

    attr_accessible :count_on_hand, :variant

    def self.locations_for_variant(variant)
      where(variant_id: variant).map(&:stock_location)
    end
  end
end
