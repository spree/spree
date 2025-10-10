module Spree
  module Api
    module V2
      module Platform
        class CustomerReturnSerializer < BaseSerializer
          include ResourceSerializerConcern

          belongs_to :stock_location, serializer: Spree::Api::Dependencies.platform_stock_location_serializer.constantize

          has_many :reimbursements, serializer: Spree::Api::Dependencies.platform_reimbursement_serializer.constantize
          has_many :return_items, serializer: Spree::Api::Dependencies.platform_return_item_serializer.constantize
          has_many :return_authorizations, serializer: Spree::Api::Dependencies.platform_return_authorization_serializer.constantize
        end
      end
    end
  end
end
