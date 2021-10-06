module Spree
  module Api
    module V2
      module Platform
        class InventoryUnitSerializer < BaseSerializer
          include ResourceSerializerConcern

          belongs_to :order
          belongs_to :variant
          belongs_to :shipment
          has_many :return_items
          has_many :return_authorizations
          belongs_to :line_item
          belongs_to :original_return_item, serializer: :return_item, type: :return_item
        end
      end
    end
  end
end
