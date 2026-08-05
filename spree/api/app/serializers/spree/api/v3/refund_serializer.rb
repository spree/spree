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

        attribute :payment_id do |refund|
          refund.payment&.prefixed_id
        end

        attribute :refund_reason_id do |refund|
          refund.reason&.prefixed_id
        end

        # What triggered this refund — a Return, Exchange or Claim; nil for a
        # manual refund.
        attribute :originator_id do |refund|
          refund.originator&.prefixed_id
        end

        attribute :originator_type do |refund|
          refund.originator_type
        end
      end
    end
  end
end
