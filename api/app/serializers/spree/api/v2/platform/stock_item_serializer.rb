module Spree
  module Api
    module V2
      module Platform
        class StockItemSerializer < BaseSerializer
          include ::Spree::Api::V2::ResourceSerializerConcern

          set_type :stock_item

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
