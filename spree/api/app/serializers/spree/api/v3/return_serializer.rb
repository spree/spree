# frozen_string_literal: true

module Spree
  module Api
    module V3
      # Customer-facing view of a return. No timestamps, no internal notes,
      # no staff attribution — see the serializer rules in CLAUDE.md.
      class ReturnSerializer < BaseSerializer
        typelize number: :string,
                 status: :string,
                 order_id: [:string, nullable: true],
                 reason_id: [:string, nullable: true],
                 refund_total: :string,
                 display_refund_total: :string,
                 approved_at: [:string, nullable: true],
                 received_at: [:string, nullable: true],
                 refunded_at: [:string, nullable: true],
                 canceled_at: [:string, nullable: true]

        attributes :number, :status

        attribute :order_id do |return_record|
          return_record.order&.prefixed_id
        end

        attribute :reason_id do |return_record|
          return_record.reason&.prefixed_id
        end

        attribute :refund_total do |return_record|
          return_record.refund_total.to_s
        end

        attribute :display_refund_total do |return_record|
          return_record.display_refund_total.to_s
        end

        attribute :approved_at do |return_record|
          return_record.approved_at&.iso8601
        end

        attribute :received_at do |return_record|
          return_record.received_at&.iso8601
        end

        attribute :refunded_at do |return_record|
          return_record.refunded_at&.iso8601
        end

        attribute :canceled_at do |return_record|
          return_record.canceled_at&.iso8601
        end

        many :return_line_items,
             resource: proc { Spree.api.return_line_item_serializer },
             if: proc { expand?('return_line_items') }
      end
    end
  end
end
