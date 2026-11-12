# frozen_string_literal: true

module Spree
  module Api
    module V3
      class ClaimLineItemSerializer < BaseSerializer
        typelize quantity: :number,
                 send_replacement: :boolean,
                 description: [:string, nullable: true],
                 variant_id: [:string, nullable: true],
                 replacement_variant_id: [:string, nullable: true],
                 line_item_id: [:string, nullable: true]

        attributes :quantity, :send_replacement, :description

        # paid_amount is what the customer actually paid for these units, tax
        # included — the ceiling the resolve workflow enforces, and what the
        # dashboard offers when the claim carries no explicit amount.
        money_attributes :refund_amount, :paid_amount, :pre_tax_amount, :included_tax_total,
                         :additional_tax_total, :tax_total, :display_refund_amount
        prefixed_id_attributes :variant, :replacement_variant, :line_item

        one :variant, resource: proc { Spree.api.variant_serializer }, if: proc { expand?('variant') }
      end
    end
  end
end
