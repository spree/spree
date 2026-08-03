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
                 variant_id: [:string, nullable: true],
                 line_item_id: [:string, nullable: true],
                 fulfillment_item_id: [:string, nullable: true]

        attributes :quantity, :received_quantity, :resellable

        attribute :pre_tax_amount do |line|
          line.pre_tax_amount.to_s
        end

        attribute :display_pre_tax_amount do |line|
          line.display_pre_tax_amount.to_s
        end

        attribute :variant_id do |line|
          line.variant&.prefixed_id
        end

        attribute :line_item_id do |line|
          line.line_item&.prefixed_id
        end

        attribute :fulfillment_item_id do |line|
          line.fulfillment_item&.prefixed_id
        end

        one :variant, resource: proc { Spree.api.variant_serializer }, if: proc { expand?('variant') }
      end
    end
  end
end
