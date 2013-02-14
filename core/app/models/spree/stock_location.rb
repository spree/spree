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
  end
end
