# frozen_string_literal: true

module Spree
  module Api
    module V3
      # Customer-facing view of an exchange.
      class ExchangeSerializer < BaseSerializer
        typelize number: :string,
                 status: [:string, enum: Spree::Exchange.statuses, enum_type_name: 'ExchangeStatus'],
                 order_id: [:string, nullable: true],
                 reason_id: [:string, nullable: true],
                 approved_at: [:string, nullable: true],
                 received_at: [:string, nullable: true],
                 fulfilled_at: [:string, nullable: true],
                 canceled_at: [:string, nullable: true],
                 cancelable: :boolean

        attributes :number, :status

        # Whether the customer may still withdraw the request: only before the
        # merchant has acted on it.
        attribute :cancelable, &:requested?

        prefixed_id_attributes :order, :reason

        money_attributes :price_difference, :display_price_difference

        attribute :approved_at do |exchange|
          exchange.approved_at&.iso8601
        end

        attribute :received_at do |exchange|
          exchange.received_at&.iso8601
        end

        attribute :fulfilled_at do |exchange|
          exchange.fulfilled_at&.iso8601
        end

        attribute :canceled_at do |exchange|
          exchange.canceled_at&.iso8601
        end

        one :reason, resource: proc { Spree.api.return_reason_serializer }, if: proc { expand?('reason') }

        # The order it belongs to — always present on webhook payloads, so a
        # storefront sending its own emails can address the customer.
        one :order, resource: proc { Spree.api.order_serializer }, if: proc { expand?('order') }

        many :exchange_line_items,
             resource: proc { Spree.api.exchange_line_item_serializer },
             if: proc { expand?('exchange_line_items') }
      end
    end
  end
end
