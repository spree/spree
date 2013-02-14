module Spree
  class StockPackage
    attr_accessor :stock_location, :contents

    def initialize(stock_location)
      @stock_location = stock_location
      @contents = Array.new
    end

    def add(stock_item)
      contents << stock_item
    end

    def weight
      contents.sum &:weight
    end

    def inspect
      contents.map do |stock_item|
        "#{stock_item.variant.name}"
      end.join(',')
    end
  end
end
