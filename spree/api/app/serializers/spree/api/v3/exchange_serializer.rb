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
                 price_difference: :string,
                 display_price_difference: :string,
                 approved_at: [:string, nullable: true],
                 received_at: [:string, nullable: true],
                 fulfilled_at: [:string, nullable: true],
                 canceled_at: [:string, nullable: true]

        attributes :number, :status

        prefixed_id_attributes :order, :reason

        string_attributes :price_difference, :display_price_difference

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

        expandable :one, :reason, :return_reason_serializer

        expandable :many, :exchange_line_items, :exchange_line_item_serializer
      end
    end
  end
end
