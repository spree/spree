module Spree
  module Api
    module V3
      module Admin
        class DiscountSerializer < V3::DiscountSerializer
          # The Admin API has no guest gating — money fields inherited from the
          # store serializer are always present, so override their nullability.
          typelize amount: [:string, nullable: false], display_amount: [:string, nullable: false]

          attributes created_at: :iso8601, updated_at: :iso8601
        end
      end
    end
  end
end
