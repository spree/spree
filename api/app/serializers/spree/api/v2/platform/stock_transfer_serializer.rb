module Spree
  module Api
    module V2
      module Platform
        class StockTransferSerializer < BaseSerializer
          include ResourceSerializerConcern

          belongs_to :destination_location, serializer: Spree::Api::Dependencies.platform_stock_location_serializer.constantize
          belongs_to :source_location, serializer: Spree::Api::Dependencies.platform_stock_location_serializer.constantize
          has_many :stock_movements, serializer: Spree::Api::Dependencies.platform_stock_movement_serializer.constantize
        end
      end
    end
  end
end
