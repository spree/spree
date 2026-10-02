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

        string_attributes :pre_tax_amount, :display_pre_tax_amount, :included_tax_total, :additional_tax_total,
                          :tax_total, :display_tax_total

        # What the line refunds, tax included — for the units that arrived
        # once the warehouse has counted.
        string_attributes :refund_amount, :display_refund_amount

        prefixed_id_attributes :variant, :line_item, :fulfillment_item

        expandable :one, :variant, :variant_serializer
      end
    end
  end
end
