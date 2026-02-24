# frozen_string_literal: true

module Spree
  module Api
    module V3
      class ReturnItemSerializer < BaseSerializer
        typelize reception_status: [:string, nullable: true], acceptance_status: [:string, nullable: true],
                 pre_tax_amount: [:string, nullable: true],
                 included_tax_total: [:string, nullable: true], additional_tax_total: [:string, nullable: true],
                 inventory_unit_id: [:string, nullable: true],
                 return_authorization_id: [:string, nullable: true],
                 customer_return_id: [:string, nullable: true],
                 reimbursement_id: [:string, nullable: true],
                 exchange_variant_id: [:string, nullable: true]

        attributes :reception_status, :acceptance_status,
                   created_at: :iso8601, updated_at: :iso8601

        attribute :pre_tax_amount do |item|
          item.pre_tax_amount&.to_s
        end

        attribute :included_tax_total do |item|
          item.included_tax_total&.to_s
        end

        attribute :additional_tax_total do |item|
          item.additional_tax_total&.to_s
        end

        attribute :inventory_unit_id do |item|
          item.inventory_unit&.prefixed_id
        end

        attribute :return_authorization_id do |item|
          item.return_authorization&.prefixed_id
        end

        attribute :customer_return_id do |item|
          item.customer_return&.prefixed_id
        end

        attribute :reimbursement_id do |item|
          item.reimbursement&.prefixed_id
        end

        attribute :exchange_variant_id do |item|
          item.exchange_variant&.prefixed_id
        end
      end
    end
  end
end
