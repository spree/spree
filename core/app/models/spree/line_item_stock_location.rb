module Spree
  class LineItemStockLocation < ActiveRecord::Base
    belongs_to :line_item, class_name: "Spree::LineItem"
    belongs_to :stock_location, class_name: "Spree::StockLocation"
  end
end