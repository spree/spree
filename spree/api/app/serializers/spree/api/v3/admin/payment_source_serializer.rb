module Spree
  module Api
    module V3
      module Admin
        class PaymentSourceSerializer < V3::PaymentSourceSerializer
          typelize metadata: 'Record<string, unknown>'

          attributes :metadata,
                     created_at: :iso8601, updated_at: :iso8601

          expandable_custom_fields admin: true
        end
      end
    end
  end
end
