module Spree
  class StockLocation < ActiveRecord::Base
    belongs_to :address
    attr_accessible :name
    has_many :stock_items, :dependent => :destroy

    validates_presence_of :name

    def stock_item(variant)
      stock_items.where(variant_id: variant).first
    end

    def count_on_hand(variant)
      stock_item(variant).try(:count_on_hand)
    end

    def decrease_stock_for_variant(variant, by = 1)
      stock_item(variant).decrement!(:count_on_hand, by)
    end

    def increase_stock_for_variant(variant, by = 1)
      stock_item(variant).increment!(:count_on_hand, by)
    end
  end
end
