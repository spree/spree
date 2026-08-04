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
                 description: [:string, nullable: true],
                 variant_id: [:string, nullable: true],
                 replacement_variant_id: [:string, nullable: true],
                 line_item_id: [:string, nullable: true]

        attributes :quantity, :send_replacement, :description

        attribute :refund_amount do |line|
          line.refund_amount.to_s
        end

        # What the customer actually paid for these units — the ceiling the
        # resolve workflow enforces, and what the dashboard offers when the
        # claim carries no explicit amount.
        attribute :paid_amount do |line|
          line.paid_amount.to_s
        end

        attribute :display_refund_amount do |line|
          line.display_refund_amount.to_s
        end

        attribute :variant_id do |line|
          line.variant&.prefixed_id
        end

        attribute :replacement_variant_id do |line|
          line.replacement_variant&.prefixed_id
        end

        attribute :line_item_id do |line|
          line.line_item&.prefixed_id
        end

        one :variant, resource: proc { Spree.api.variant_serializer }, if: proc { expand?('variant') }
      end
    end
  end
end
