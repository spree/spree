module Spree
  class StockItemSerializer < ActiveModel::Serializer
    attributes :id, :count_on_hand, :stock_location_id, :backorderable,
               :available, :stock_location_name

    def available
      object.available?
    end

    def stock_location_name
      object.stock_location.name
    end
  end
end