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
                   refundable_total: :string

          attributes :memo, :metadata, created_at: :iso8601, updated_at: :iso8601

          attribute :stock_location_id do |return_record|
            return_record.stock_location&.prefixed_id
          end

          attribute :created_by_id do |return_record|
            return_record.created_by&.prefixed_id
          end

          # `admin_user` / `api_key` — which kind of actor the id names.
          attribute :created_by_type do |return_record|
            Spree::Base.polymorphic_api_type(return_record.acted_by_type(:created_by))
          end

          one :created_by,
              resource: proc { Spree.api.admin_actor_serializer },
              if: proc { expand?('created_by') }

          attribute :refunded_total do |return_record|
            return_record.refunded_total.to_s
          end

          attribute :refundable_total do |return_record|
            return_record.refundable_total.to_s
          end

          many :return_line_items,
               resource: proc { Spree.api.admin_return_line_item_serializer },
               if: proc { expand?('return_line_items') }

          one :reason, resource: proc { Spree.api.admin_return_reason_serializer }, if: proc { expand?('reason') }
          one :order, resource: proc { Spree.api.admin_order_serializer }, if: proc { expand?('order') }
          one :stock_location, resource: proc { Spree.api.admin_stock_location_serializer }, if: proc { expand?('stock_location') }
          many :refunds, resource: proc { Spree.api.admin_refund_serializer }, if: proc { expand?('refunds') }

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
