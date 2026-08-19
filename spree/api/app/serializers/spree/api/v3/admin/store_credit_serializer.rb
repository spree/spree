module Spree
  module Api
    module V3
      module Admin
        class StoreCreditSerializer < V3::StoreCreditSerializer
          typelize customer_id: [:string, nullable: true],
                   created_by_id: [:string, nullable: true],
                   memo: [:string, nullable: true],
                   metadata: 'Record<string, unknown>'

          attributes :memo, :metadata,
                     created_at: :iso8601, updated_at: :iso8601

          attribute :customer_id do |store_credit|
            store_credit.customer&.prefixed_id
          end

          attribute :created_by_id do |store_credit|
            store_credit.created_by&.prefixed_id
          end
        end
      end
    end
  end
end
