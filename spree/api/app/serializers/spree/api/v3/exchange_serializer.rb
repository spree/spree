# frozen_string_literal: true

module Spree
  module Api
    module V3
      # Customer-facing view of an exchange.
      class ExchangeSerializer < BaseSerializer
        typelize number: :string,
                 status: :string,
                 order_id: [:string, nullable: true],
                 reason_id: [:string, nullable: true],
                 price_difference: :string,
                 display_price_difference: :string,
                 approved_at: [:string, nullable: true],
                 received_at: [:string, nullable: true],
                 fulfilled_at: [:string, nullable: true],
                 canceled_at: [:string, nullable: true]

        attributes :number, :status

        attribute :order_id do |exchange|
          exchange.order&.prefixed_id
        end

        attribute :reason_id do |exchange|
          exchange.reason&.prefixed_id
        end

        attribute :price_difference do |exchange|
          exchange.price_difference.to_s
        end

        attribute :display_price_difference do |exchange|
          exchange.display_price_difference.to_s
        end

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

        many :exchange_line_items,
             resource: proc { Spree.api.exchange_line_item_serializer },
             if: proc { expand?('exchange_line_items') }
      end
    end
  end
end
