module Spree
  module Api
    module V2
      module Platform
        class RefundSerializer < BaseSerializer
          include ResourceSerializerConcern

          belongs_to :refunder, serializer: Spree::Api::Dependencies.platform_admin_user_serializer.constantize
          belongs_to :payment, serializer: Spree::Api::Dependencies.platform_payment_serializer.constantize
          belongs_to :reimbursement, serializer: Spree::Api::Dependencies.platform_reimbursement_serializer.constantize
          belongs_to :refund_reason, object_method_name: :reason, serializer: Spree::Api::Dependencies.platform_refund_reason_serializer.constantize
          has_many :log_entries, serializer: Spree::Api::Dependencies.platform_log_entry_serializer.constantize
        end
      end
    end
  end
end
