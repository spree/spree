module Spree
  module Api
    module V3
      module Admin
        class CreditCardSerializer < V3::CreditCardSerializer
          typelize customer_id: [:string, nullable: true],
                   payment_method_id: [:string, nullable: true],
                   metadata: 'Record<string, unknown>'

          prefixed_id_attributes :customer, :payment_method

          attributes :metadata,
                     created_at: :iso8601, updated_at: :iso8601

          expandable_custom_fields admin: true
        end
      end
    end
  end
end
