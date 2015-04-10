module Spree
  class OrderMerger
    attr_accessor :order
    delegate :updater, to: :order

    def initialize(order)
      @order = order
    end

    def merge!(other)
      other.line_items.each do |line_item|
        next unless line_item.currency == order.currency
        order.contents.add(line_item.variant, line_item.quantity)
      end
      other.destroy
      order
    end
  end
end
