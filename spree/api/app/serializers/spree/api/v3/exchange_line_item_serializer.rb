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
                 original_variant_id: [:string, nullable: true],
                 new_variant_id: [:string, nullable: true],
                 line_item_id: [:string, nullable: true],
                 fulfillment_item_id: [:string, nullable: true]

        attributes :quantity, :received_quantity, :resellable

        attribute :original_price do |line|
          line.original_price.to_s
        end

        attribute :new_variant_price do |line|
          line.new_variant_price.to_s
        end

        attribute :price_difference do |line|
          line.price_difference.to_s
        end

        attribute :original_variant_id do |line|
          line.original_variant&.prefixed_id
        end

        attribute :new_variant_id do |line|
          line.new_variant&.prefixed_id
        end

        attribute :line_item_id do |line|
          line.line_item&.prefixed_id
        end

        attribute :fulfillment_item_id do |line|
          line.fulfillment_item&.prefixed_id
        end

        one :original_variant, resource: proc { Spree.api.variant_serializer }, if: proc { expand?('original_variant') }
        one :new_variant, resource: proc { Spree.api.variant_serializer }, if: proc { expand?('new_variant') }
      end
    end
  end
end
