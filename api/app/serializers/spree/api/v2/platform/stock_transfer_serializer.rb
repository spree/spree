module Spree
  module Api
    module V2
      module Platform
        class StockTransferSerializer < BaseSerializer
          include ResourceSerializerConcern

          belongs_to :destination_location, serializer: :stock_location
          belongs_to :source_location, serializer: :stock_location
          has_many :stock_movements
        end
      end
    end
  end
end
