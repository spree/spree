# frozen_string_literal: true

module Spree
  module Api
    module V3
      class ReturnLineItemSerializer < BaseSerializer
        typelize quantity: :number,
                 received_quantity: :number,
                 resellable: :boolean,
                 variant_id: [:string, nullable: true],
                 line_item_id: [:string, nullable: true],
                 fulfillment_item_id: [:string, nullable: true]

        attributes :quantity, :received_quantity, :resellable

        money_attributes :pre_tax_amount, :display_pre_tax_amount, :included_tax_total,
                         :additional_tax_total, :tax_total, :display_tax_total
        # What the line refunds, tax included — for the units that arrived
        # once the warehouse has counted.
        money_attributes :refund_amount, :display_refund_amount
        prefixed_id_attributes :variant, :line_item, :fulfillment_item

        one :variant, resource: proc { Spree.api.variant_serializer }, if: proc { expand?('variant') }
      end
    end
  end
end
