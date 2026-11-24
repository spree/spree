# frozen_string_literal: true

module Spree
  module Api
    module V3
      class RefundSerializer < BaseSerializer
        typelize transaction_id: [:string, nullable: true],
                 payment_id: [:string, nullable: true], refund_reason_id: [:string, nullable: true],
                 originator_id: [:string, nullable: true], originator_type: [:string, nullable: true],
                 reimbursement_id: [:string, nullable: true, deprecated: 'Always null: reimbursements are gone. Use `originator_id`. Removed in 6.5.']

        attributes :transaction_id

        money_attributes :amount

        prefixed_id_attributes :payment, refund_reason_id: :reason

        # What triggered this refund — a Return, Exchange or Claim; nil for a
        # manual refund.
        prefixed_id_attributes :originator

        attribute :originator_type do |refund|
          Spree::Base.polymorphic_api_type(refund.originator_type)
        end

        # Read from the column, so a list of refunds loads no credits.
        typelize store_credit_id: [
          :string, { nullable: true, comment: 'The store credit the money went back as; null when it went back to the payment.' }
        ]
        attribute :store_credit_id do |refund|
          Spree::StoreCredit.prefixed_id_for(refund.store_credit_id)
        end

        # @deprecated Reimbursements were folded into returns, which a refund
        #   names as its +originator+. Removed in 6.5.
        attribute(:reimbursement_id) { nil }
      end
    end
  end
end
