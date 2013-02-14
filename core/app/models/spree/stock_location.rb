module Spree
  class StockLocation < ActiveRecord::Base
    belongs_to :address
    attr_accessible :name
    has_many :stock_items, :dependent => :destroy

    validates_presence_of :name

    def packages(order)
      packages = [default_package(order)]
      splitter(order).split(packages)
    end

    def default_package(order)
      package = StockPackage.new(self)
      order.line_items.each do |line_item|
        on_hand, backordered = stock_status(line_item.variant, line_item.quantity)
        package.add line_item.variant, on_hand, :on_hand if on_hand > 0
        package.add line_item.variant, backordered, :backordered if backordered > 0
      end
      package
    end

    def splitter(order)
      # TODO build a chain of splitters
      StockSplitter::Base.new(self, order)
    end

    private
    def stock_item(variant)
      stock_items.where(variant_id: variant).first
    end

    def stock_status(variant, quantity)
      item = stock_item(variant)

      if item.count_on_hand >= quantity
        on_hand = quantity
        backordered = 0
      else
        on_hand = item.count_on_hand
        backordered = quantity - on_hand
      end

      [on_hand, backordered]
    end

    def count_on_hand(variant)
      stock_item = stock_items.where(variant_id: variant).first
      stock_item.try(:count_on_hand)
    end
  end
end
