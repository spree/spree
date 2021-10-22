module Spree
  module Api
    module V2
      module Platform
        class StockItemSerializer < BaseSerializer
          include ResourceSerializerConcern

          attribute :is_available do |stock_item|
            stock_item.available?
          end

          belongs_to :stock_location
          belongs_to :variant
        end
      end
    end
  end
end
