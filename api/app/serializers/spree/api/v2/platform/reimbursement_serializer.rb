module Spree
  module Api
    module V2
      module Platform
        class ReimbursementSerializer < BaseSerializer
          include ResourceSerializerConcern

          belongs_to :order, serializer: Spree::Api::Dependencies.platform_order_serializer.constantize
          belongs_to :customer_return, serializer: Spree::Api::Dependencies.platform_customer_return_serializer.constantize
          belongs_to :performed_by, serializer: Spree::Api::Dependencies.platform_admin_user_serializer.constantize

          has_many :refunds, serializer: Spree::Api::Dependencies.platform_refund_serializer.constantize
          has_many :reimbursement_credits, object_method_name: :credits, id_method_name: :credit_ids, serializer: Spree::Api::Dependencies.platform_reimbursement_credit_serializer.constantize
          has_many :return_items, serializer: Spree::Api::Dependencies.platform_return_item_serializer.constantize
        end
      end
    end
  end
end
