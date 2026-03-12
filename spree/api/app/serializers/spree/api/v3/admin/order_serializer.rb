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
                   user_id: [:string, nullable: true],
                   canceled_at: [:string, nullable: true], approved_at: [:string, nullable: true],
                   payment_total: :string, display_payment_total: :string,
                   metadata: 'Record<string, unknown> | null'

          # Admin-only attributes
          attributes :channel, :last_ip_address, :considered_risky,
                     :confirmation_delivered, :store_owner_notification_delivered,
                     :internal_note, :payment_total, :display_payment_total,
                     canceled_at: :iso8601, approved_at: :iso8601

          attribute :metadata do |order|
            order.metadata.presence
          end

          attribute :approver_id do |order|
            order.approver&.prefixed_id
          end

          attribute :canceler_id do |order|
            order.canceler&.prefixed_id
          end

          attribute :created_by_id do |order|
            order.created_by&.prefixed_id
          end

          attribute :user_id do |order|
            order.user&.prefixed_id
          end

          # Override inherited associations to use admin serializers
          many :order_promotions, key: :promotions, resource: Spree.api.admin_order_promotion_serializer, if: proc { expand?('promotions') }
          many :line_items, key: :items, resource: Spree.api.admin_line_item_serializer, if: proc { expand?('items') }
          many :shipments, resource: Spree.api.admin_shipment_serializer, if: proc { expand?('shipments') }
          many :payments, resource: Spree.api.admin_payment_serializer, if: proc { expand?('payments') }

          one :bill_address, resource: Spree.api.admin_address_serializer, if: proc { expand?('bill_address') }
          one :ship_address, resource: Spree.api.admin_address_serializer, if: proc { expand?('ship_address') }

          many :payment_methods, resource: Spree.api.admin_payment_method_serializer, if: proc { expand?('payment_methods') }

          one :user,
              resource: Spree.api.admin_customer_serializer,
              if: proc { expand?('user') }

          one :approver,
              resource: Spree.api.admin_customer_serializer,
              if: proc { expand?('approver') }

          one :canceler,
              resource: Spree.api.admin_customer_serializer,
              if: proc { expand?('canceler') }

          one :created_by,
              resource: Spree.api.admin_customer_serializer,
              if: proc { expand?('created_by') }

          many :adjustments,
               resource: Spree.api.admin_adjustment_serializer,
               if: proc { expand?('adjustments') }

          many :return_authorizations,
               resource: Spree.api.admin_return_authorization_serializer,
               if: proc { expand?('return_authorizations') }

          many :reimbursements,
               resource: Spree.api.admin_reimbursement_serializer,
               if: proc { expand?('reimbursements') }
        end
      end
    end
  end
end
