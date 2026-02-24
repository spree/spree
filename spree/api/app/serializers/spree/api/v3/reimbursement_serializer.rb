# frozen_string_literal: true

module Spree
  module Api
    module V3
      class ReimbursementSerializer < BaseSerializer
        typelize number: :string, reimbursement_status: [:string, nullable: true],
                 total: [:string, nullable: true],
                 order_id: [:string, nullable: true], customer_return_id: [:string, nullable: true]

        attributes :number, :reimbursement_status,
                   created_at: :iso8601, updated_at: :iso8601

        attribute :total do |reimbursement|
          reimbursement.total&.to_s
        end

        attribute :order_id do |reimbursement|
          reimbursement.order&.prefixed_id
        end

        attribute :customer_return_id do |reimbursement|
          reimbursement.customer_return&.prefixed_id
        end
      end
    end
  end
end
