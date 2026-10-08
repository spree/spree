# frozen_string_literal: true

module Spree
  module Api
    module V3
      class RefundSerializer < BaseSerializer
        typelize amount: [:string, nullable: true], transaction_id: [:string, nullable: true],
                 payment_id: [:string, nullable: true], refund_reason_id: [:string, nullable: true],
                 originator_id: [:string, nullable: true], originator_type: [:string, nullable: true]

        attributes :transaction_id

        attribute :amount do |refund|
          refund.amount&.to_s
        end

        prefixed_id_attributes :payment, refund_reason_id: :reason

        # What triggered this refund — a Return, Exchange or Claim; nil for a
        # manual refund.
        prefixed_id_attributes :originator

        attributes :originator_type
      end
    end
  end
end
