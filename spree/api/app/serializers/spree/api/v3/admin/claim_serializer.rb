# frozen_string_literal: true

module Spree
  module Api
    module V3
      module Admin
        class ClaimSerializer < V3::ClaimSerializer
          typelize memo: [:string, nullable: true],
                   metadata: 'Record<string, unknown>',
                   created_by_id: [:string, nullable: true]

          attributes :memo, :metadata, created_at: :iso8601, updated_at: :iso8601

          attribute :created_by_id do |claim|
            claim.created_by&.prefixed_id
          end

          many :claim_line_items,
               resource: proc { Spree.api.admin_claim_line_item_serializer },
               if: proc { expand?('claim_line_items') }

          one :order, resource: proc { Spree.api.admin_order_serializer }, if: proc { expand?('order') }
          many :refunds, resource: proc { Spree.api.admin_refund_serializer }, if: proc { expand?('refunds') }
        end
      end
    end
  end
end
