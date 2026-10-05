# frozen_string_literal: true

module Spree
  module Api
    module V3
      class ClaimLineItemSerializer < BaseSerializer
        typelize quantity: :number,
                 send_replacement: :boolean,
                 refund_amount: :string,
                 display_refund_amount: :string,
                 paid_amount: :string,
                 pre_tax_amount: :string,
                 included_tax_total: :string,
                 additional_tax_total: :string,
                 tax_total: :string,
                 description: [:string, nullable: true],
                 variant_id: [:string, nullable: true],
                 replacement_variant_id: [:string, nullable: true],
                 line_item_id: [:string, nullable: true]

        attributes :quantity, :send_replacement, :description

        attributes refund_amount: :string
        # What the customer actually paid for these units, tax included — the
        # ceiling the resolve workflow enforces, and what the dashboard offers
        # when the claim carries no explicit amount.
        attributes paid_amount: :string, pre_tax_amount: :string, included_tax_total: :string,
                   additional_tax_total: :string, tax_total: :string, display_refund_amount: :string
        prefixed_id_attributes :variant, :replacement_variant, :line_item

        one :variant, resource: proc { Spree.api.variant_serializer }, if: proc { expand?('variant') }
      end
    end
  end
end
