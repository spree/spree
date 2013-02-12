module Spree
  class StockLocation < ActiveRecord::Base
    belongs_to :address
    attr_accessible :name
    has_many :stock_items, :dependent => :destroy

    def count_on_hand(variant_id)
      stock_item = stock_items.where(variant_id: variant_id).first
      stock_item.try(:count_on_hand)
    end
  end
end
