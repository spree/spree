module Spree
  class StockPackage
    ContentItem = Struct.new(:variant, :quantity, :status)

    attr_accessor :stock_location, :contents

    def initialize(stock_location)
      @stock_location = stock_location
      @contents = Array.new
    end

    def add(variant, quantity, status=:on_hand)
      contents << ContentItem.new(variant, quantity, status)
    end

    def weight
      contents.sum { |item| item.variant.weight }
    end

    def on_hand
      contents.select { |item| item.status == :on_hand }
    end

    def backordered
      contents.select { |item| item.status == :backordered }
    end

    def inspect
      contents.map do |content_item|
        "#{content_item.variant.name} #{content_item.quantity} #{content_item.status}"
      end.join(',')
    end
  end
end
