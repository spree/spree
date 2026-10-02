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

        attribute :pre_tax_amount do |line|
          line.pre_tax_amount.to_s
        end

        attribute :display_pre_tax_amount do |line|
          line.display_pre_tax_amount.to_s
        end

        attribute :included_tax_total do |line|
          line.included_tax_total.to_s
        end

        attribute :additional_tax_total do |line|
          line.additional_tax_total.to_s
        end

        attribute :tax_total do |line|
          line.tax_total.to_s
        end

        attribute :display_tax_total do |line|
          line.display_tax_total.to_s
        end

        # What the line refunds, tax included — for the units that arrived
        # once the warehouse has counted.
        attribute :refund_amount do |line|
          line.refund_amount.to_s
        end

        attribute :display_refund_amount do |line|
          line.display_refund_amount.to_s
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
