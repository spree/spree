# frozen_string_literal: true

module Spree
  module Api
    module V3
      class ExchangeLineItemSerializer < BaseSerializer
        typelize quantity: :number,
                 received_quantity: :number,
                 resellable: :boolean,
                 original_price: :string,
                 new_variant_price: :string,
                 price_difference: :string,
                 original_tax_total: :string,
                 new_tax_total: :string,
                 original_variant_id: [:string, nullable: true],
                 new_variant_id: [:string, nullable: true],
                 line_item_id: [:string, nullable: true],
                 fulfillment_item_id: [:string, nullable: true]

        attributes :quantity, :received_quantity, :resellable

        # What the customer paid for the units coming back, after discounts
        # and with their tax.
        string_attributes :original_price

        # The replacement at the same discount, with its own tax.
        string_attributes :new_variant_price, :price_difference, :original_tax_total, :new_tax_total

        prefixed_id_attributes :original_variant, :new_variant, :line_item, :fulfillment_item

        expandable :one, :original_variant, :variant_serializer
        expandable :one, :new_variant, :variant_serializer
      end
    end
  end
end
