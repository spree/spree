module Spree
  module Api
    module V2
      module Platform
        class StockItemSerializer < BaseSerializer
          include ResourceSerializerConcern

          attribute :is_available do |stock_item|
            stock_item.available?
          end

          belongs_to :stock_location, serializer: Spree::Api::Dependencies.platform_stock_location_serializer.constantize
          belongs_to :variant, serializer: Spree::Api::Dependencies.platform_variant_serializer.constantize
        end
      end
    end
  end
end
