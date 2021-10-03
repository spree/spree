module Spree
  module Api
    module V2
      module Platform
        class OrderSerializer < BaseSerializer
          include ResourceSerializerConcern

          belongs_to :user
          belongs_to :created_by, serializer: Dependencies.platform_admin_user_serializer.constantize
          belongs_to :approver, serializer: Dependencies.platform_admin_user_serializer.constantize
          belongs_to :canceler, serializer: Dependencies.platform_admin_user_serializer.constantize

          belongs_to :bill_address, serializer: AddressSerializer
          belongs_to :ship_address, serializer: AddressSerializer

          has_many :line_items
          has_many :payments
          has_many :shipments

          has_many :state_changes
          has_many :return_authorizations
          has_many :reimbursements
          has_many :adjustments
          has_many :all_adjustments, serializer: :adjustments, type: :adjustment

          has_many :order_promotions
        end
      end
    end
  end
end
