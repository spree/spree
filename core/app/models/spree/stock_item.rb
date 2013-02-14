module Spree
  class StockItem < ActiveRecord::Base
    belongs_to :stock_location
    belongs_to :variant

    # can_backorder?
    #
    validates_presence_of :stock_location
    validates_uniqueness_of :variant_id, :scope => :stock_location_id

    attr_accessible :count_on_hand, :variant

    delegate :weight, :to => :variant

    def self.locations_for_variant(variant)
      where(variant_id: variant).map(&:stock_location)
    end
  end
end
