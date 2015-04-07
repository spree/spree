module Spree
  class StockMovementSerializer < ActiveModel::Serializer
    attributes :id, :stock_item_id, :quantity

    has_one :stock_item
  end
end