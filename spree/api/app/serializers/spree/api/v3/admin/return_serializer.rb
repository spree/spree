# frozen_string_literal: true

module Spree
  module Api
    module V3
      module Admin
        class ReturnSerializer < V3::ReturnSerializer
          typelize memo: [:string, nullable: true],
                   metadata: 'Record<string, unknown>',
                   documents: "Array<{ kind: string; url: string }>",
                   stock_location_id: [:string, nullable: true],
                   created_by_id: [:string, nullable: true],
                   created_by_type: [:string, nullable: true, enum: Spree::Actor::BUILT_IN_KINDS, enum_type_name: 'ActorKind'],
                   refunded_total: :string,
                   display_refunded_total: :string,
                   refundable_total: :string

          attributes :memo, :metadata, created_at: :iso8601, updated_at: :iso8601

          prefixed_id_attributes :stock_location

          actor_attributes :created_by

          string_attributes :refunded_total, :display_refunded_total, :refundable_total

          expandable :many, :return_line_items, :admin_return_line_item_serializer

          expandable :one, :reason, :admin_return_reason_serializer
          expandable :one, :order, :admin_order_serializer
          expandable :one, :stock_location, :admin_stock_location_serializer
          expandable :many, :refunds, :admin_refund_serializer

          # Paperwork the provider produced beside the label: a cross-border
          # return is declared like any other export.
          attribute :documents do |return_record|
            return_record.provider.documents(return_record).map(&:as_json)
          end

          # The prepaid label for the parcel coming back, refunded ones
          # included — the postage history of the return.
          many :shipping_labels, key: :labels, resource: proc { Spree.api.admin_shipping_label_serializer }

          # Where the inbound parcel is, as the carrier last reported it.
          many :deliveries, resource: proc { Spree.api.admin_delivery_serializer }
        end
      end
    end
  end
end
