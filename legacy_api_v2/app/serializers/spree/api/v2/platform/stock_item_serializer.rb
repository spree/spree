module Spree
  module Api
    module V2
      module Platform
        class StockItemSerializer < BaseSerializer
          include ResourceSerializerConcern

          attribute :is_available do |stock_item|
            stock_item.available?
          end

          belongs_to :stock_location, serializer: Spree.api.platform_stock_location_serializer
          belongs_to :variant, serializer: Spree.api.platform_variant_serializer
        end
      end
    end
  end
end
