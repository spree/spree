# frozen_string_literal: true

module Spree
  module Api
    module V3
      class ExchangeLineItemSerializer < BaseSerializer
        typelize quantity: :number,
                 received_quantity: [:number, comment: 'Units that have arrived so far, across every receipt'],
                 resellable_quantity: [:number, comment: 'Received units that went back into sellable stock'],
                 resellable: [:boolean, comment: 'Whether every received unit can be resold'],
                 original_variant_id: [:string, nullable: true],
                 new_variant_id: [:string, nullable: true],
                 line_item_id: [:string, nullable: true],
                 fulfillment_item_id: [:string, nullable: true]

        attributes :quantity, :received_quantity, :resellable_quantity, :resellable

        # What the customer paid for the units coming back, after discounts
        # and with their tax.
        money_attributes :original_price
        # The replacement at the same discount, with its own tax.
        money_attributes :new_variant_price, :price_difference, :original_tax_total, :new_tax_total
        prefixed_id_attributes :original_variant, :new_variant, :line_item, :fulfillment_item

        one :original_variant, resource: proc { Spree.api.variant_serializer }, if: proc { expand?('original_variant') }
        one :new_variant, resource: proc { Spree.api.variant_serializer }, if: proc { expand?('new_variant') }
      end
    end
  end
end
