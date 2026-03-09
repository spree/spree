module Spree
  module Api
    module V3
      module Admin
        class StoreCreditSerializer < V3::StoreCreditSerializer
          typelize user_id: [:string, nullable: true],
                   created_by_id: [:string, nullable: true],
                   metadata: 'Record<string, unknown> | null'

          attribute :user_id do |store_credit|
            store_credit.user&.prefixed_id
          end

          attribute :created_by_id do |store_credit|
            store_credit.created_by&.prefixed_id
          end

          attribute :metadata do |store_credit|
            store_credit.metadata.presence
          end

          attributes created_at: :iso8601, updated_at: :iso8601
        end
      end
    end
  end
end
