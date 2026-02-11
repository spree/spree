module Spree
  module Api
    module V3
      module Admin
        # Admin API Order Serializer
        # Full order data including admin-only fields
        class OrderSerializer < V3::OrderSerializer

          typelize channel: 'string | null', last_ip_address: 'string | null',
                   considered_risky: :boolean, confirmation_delivered: :boolean,
                   store_owner_notification_delivered: :boolean,
                   internal_note: 'string | null', approver_id: 'string | null',
                   canceler_id: 'string | null', created_by_id: 'string | null',
                   canceled_at: 'string | null', approved_at: 'string | null'

          # Admin-only attributes
          attributes :channel, :last_ip_address, :considered_risky,
                     :confirmation_delivered, :store_owner_notification_delivered,
                     :internal_note, :approver_id,
                     canceled_at: :iso8601, approved_at: :iso8601

          attribute :canceler_id do |order|
            order.canceler_id
          end

          attribute :created_by_id do |order|
            order.created_by_id
          end

          one :user,
              resource: Spree.api.admin_customer_serializer,
              if: proc { params[:includes]&.include?('user') }

          # TODO: Add adjustments associations when Admin API is implemented
        end
      end
    end
  end
end
