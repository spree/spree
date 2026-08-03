module Spree
  module Api
    module V3
      module Admin
        class DiscountSerializer < V3::DiscountSerializer
          typelize amount: [:string, nullable: false], display_amount: [:string, nullable: false],
                   metadata: ['Record<string, unknown>', nullable: true]

          attributes :metadata, created_at: :iso8601, updated_at: :iso8601
        end
      end
    end
  end
end
