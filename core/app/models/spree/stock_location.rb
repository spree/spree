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
        line_item.quantity.times do
          package.add stock_item_for_variant(line_item.variant)
        end
      end
      package
    end

    def splitter(order)
      # TODO build a chain of splitters
      StockSplitter::Base.new(self, order)
    end

    private
    def stock_item_for_variant(variant)
      stock_items.first
    end

    def count_on_hand(variant_id)
      stock_item = stock_items.where(variant_id: variant_id).first
      stock_item.try(:count_on_hand)
    end
  end
end
