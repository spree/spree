module Spree
  module Api
    module V2
      module Platform
        class OrderSerializer < BaseSerializer
          include ResourceSerializerConcern

          belongs_to :user, serializer: Spree::Api::Dependencies.platform_user_serializer.constantize
          belongs_to :created_by, serializer: Spree::Api::Dependencies.platform_admin_user_serializer.constantize
          belongs_to :approver, serializer: Spree::Api::Dependencies.platform_admin_user_serializer.constantize
          belongs_to :canceler, serializer: Spree::Api::Dependencies.platform_admin_user_serializer.constantize

          belongs_to :bill_address, serializer: Spree::Api::Dependencies.platform_address_serializer.constantize
          belongs_to :ship_address, serializer: Spree::Api::Dependencies.platform_address_serializer.constantize

          has_many :line_items, serializer: Spree::Api::Dependencies.platform_line_item_serializer.constantize
          has_many :payments, serializer: Spree::Api::Dependencies.platform_payment_serializer.constantize
          has_many :shipments, serializer: Spree::Api::Dependencies.platform_shipment_serializer.constantize

          has_many :state_changes, serializer: Spree::Api::Dependencies.platform_state_change_serializer.constantize
          has_many :return_authorizations, serializer: Spree::Api::Dependencies.platform_return_authorization_serializer.constantize
          has_many :reimbursements, serializer: Spree::Api::Dependencies.platform_reimbursement_serializer.constantize
          has_many :adjustments, serializer: Spree::Api::Dependencies.platform_adjustment_serializer.constantize
          has_many :all_adjustments, serializer: Spree::Api::Dependencies.platform_adjustment_serializer.constantize, type: :adjustment

          has_many :order_promotions, serializer: Spree::Api::Dependencies.platform_order_promotion_serializer.constantize
        end
      end
    end
  end
end
