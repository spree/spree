module Spree
  module Api
    module V3
      module Admin
        # Admin API Order Serializer
        # Full order data including admin-only fields
        class OrderSerializer < V3::OrderSerializer

          typelize channel: [:string, nullable: true], last_ip_address: [:string, nullable: true],
                   considered_risky: :boolean, confirmation_delivered: :boolean,
                   store_owner_notification_delivered: :boolean,
                   internal_note: [:string, nullable: true], approver_id: [:string, nullable: true],
                   canceler_id: [:string, nullable: true], created_by_id: [:string, nullable: true],
                   canceled_at: [:string, nullable: true], approved_at: [:string, nullable: true],
                   metadata: 'Record<string, unknown> | null'

          # Admin-only attributes
          attributes :channel, :last_ip_address, :considered_risky,
                     :confirmation_delivered, :store_owner_notification_delivered,
                     :internal_note, :approver_id,
                     canceled_at: :iso8601, approved_at: :iso8601

          attribute :metadata do |order|
            order.metadata.presence
          end

          attribute :canceler_id do |order|
            order.canceler_id
          end

          attribute :created_by_id do |order|
            order.created_by_id
          end

          many :line_items, resource: Spree.api.admin_line_item_serializer

          one :user,
              resource: Spree.api.admin_customer_serializer,
              if: proc { params[:includes]&.include?('user') }

          # TODO: Add adjustments associations when Admin API is implemented
        end
      end
    end
  end
end
