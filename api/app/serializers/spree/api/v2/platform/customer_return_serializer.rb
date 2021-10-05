module Spree
  module Api
    module V2
      module Platform
        class CustomerReturnSerializer < BaseSerializer
          include ResourceSerializerConcern

          belongs_to :stock_location

          has_many :reimbursements
          has_many :return_items
          has_many :return_authorizations
        end
      end
    end
  end
end
