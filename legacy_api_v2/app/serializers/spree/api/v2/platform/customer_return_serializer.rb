module Spree
  module Api
    module V2
      module Platform
        class CustomerReturnSerializer < BaseSerializer
          include ResourceSerializerConcern

          belongs_to :stock_location, serializer: Spree.api.platform_stock_location_serializer

          has_many :reimbursements, serializer: Spree.api.platform_reimbursement_serializer
          has_many :return_items, serializer: Spree.api.platform_return_item_serializer
          has_many :return_authorizations, serializer: Spree.api.platform_return_authorization_serializer
        end
      end
    end
  end
end
