# frozen_string_literal: true

module Spree
  module Api
    module V3
      class ReturnLineItemSerializer < BaseSerializer
        typelize quantity: :number,
                 received_quantity: :number,
                 resellable: :boolean,
                 pre_tax_amount: :string,
                 display_pre_tax_amount: :string,
                 included_tax_total: :string,
                 additional_tax_total: :string,
                 tax_total: :string,
                 display_tax_total: :string,
                 refund_amount: :string,
                 display_refund_amount: :string,
                 variant_id: [:string, nullable: true],
                 line_item_id: [:string, nullable: true],
                 fulfillment_item_id: [:string, nullable: true]

        attributes :quantity, :received_quantity, :resellable

        attributes pre_tax_amount: :string, display_pre_tax_amount: :string, included_tax_total: :string,
                   additional_tax_total: :string, tax_total: :string, display_tax_total: :string
        # What the line refunds, tax included — for the units that arrived
        # once the warehouse has counted.
        attributes refund_amount: :string, display_refund_amount: :string
        prefixed_id_attributes :variant, :line_item, :fulfillment_item

        one :variant, resource: proc { Spree.api.variant_serializer }, if: proc { expand?('variant') }
      end
    end
  end
end
