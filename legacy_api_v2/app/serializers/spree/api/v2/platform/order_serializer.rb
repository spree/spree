module Spree
  module Api
    module V2
      module Platform
        class OrderSerializer < BaseSerializer
          include ResourceSerializerConcern

          belongs_to :user, serializer: Spree.api.platform_user_serializer
          belongs_to :created_by, serializer: Spree.api.platform_admin_user_serializer
          belongs_to :approver, serializer: Spree.api.platform_admin_user_serializer
          belongs_to :canceler, serializer: Spree.api.platform_admin_user_serializer

          belongs_to :bill_address, serializer: Spree.api.platform_address_serializer
          belongs_to :ship_address, serializer: Spree.api.platform_address_serializer

          has_many :line_items, serializer: Spree.api.platform_line_item_serializer
          has_many :payments, serializer: Spree.api.platform_payment_serializer
          has_many :shipments, serializer: Spree.api.platform_shipment_serializer

          has_many :state_changes, serializer: Spree.api.platform_state_change_serializer
          has_many :return_authorizations, serializer: Spree.api.platform_return_authorization_serializer
          has_many :reimbursements, serializer: Spree.api.platform_reimbursement_serializer
          has_many :adjustments, serializer: Spree.api.platform_adjustment_serializer
          has_many :all_adjustments, serializer: Spree.api.platform_adjustment_serializer, type: :adjustment

          has_many :order_promotions, serializer: Spree.api.platform_order_promotion_serializer
        end
      end
    end
  end
end
