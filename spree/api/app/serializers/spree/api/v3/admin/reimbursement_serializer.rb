module Spree
  module Api
    module V3
      module Admin
        class ReimbursementSerializer < V3::ReimbursementSerializer
          attributes created_at: :iso8601, updated_at: :iso8601

          one :order,
              resource: proc { Spree.api.admin_order_serializer },
              if: proc { expand?('order') }
        end
      end
    end
  end
end
