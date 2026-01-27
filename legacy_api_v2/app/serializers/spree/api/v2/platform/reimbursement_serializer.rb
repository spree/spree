module Spree
  module Api
    module V2
      module Platform
        class ReimbursementSerializer < BaseSerializer
          include ResourceSerializerConcern

          belongs_to :order, serializer: Spree.api.platform_order_serializer
          belongs_to :customer_return, serializer: Spree.api.platform_customer_return_serializer
          belongs_to :performed_by, serializer: Spree.api.platform_admin_user_serializer

          has_many :refunds, serializer: Spree.api.platform_refund_serializer
          has_many :reimbursement_credits, object_method_name: :credits, id_method_name: :credit_ids, serializer: Spree.api.platform_reimbursement_credit_serializer
          has_many :return_items, serializer: Spree.api.platform_return_item_serializer
        end
      end
    end
  end
end
