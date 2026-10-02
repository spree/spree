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
        attributes original_price: :string
        # The replacement at the same discount, with its own tax.
        attributes new_variant_price: :string, price_difference: :string, original_tax_total: :string,
                   new_tax_total: :string
        prefixed_id_attributes :original_variant, :new_variant, :line_item, :fulfillment_item

        one :original_variant, resource: proc { Spree.api.variant_serializer }, if: proc { expand?('original_variant') }
        one :new_variant, resource: proc { Spree.api.variant_serializer }, if: proc { expand?('new_variant') }
      end
    end
  end
end
