module Spree
  module Api
    module V3
      module Admin
        class ReimbursementSerializer < V3::ReimbursementSerializer
          one :order,
              resource: Spree.api.admin_order_serializer,
              if: proc { expand?('order') }
        end
      end
    end
  end
end
