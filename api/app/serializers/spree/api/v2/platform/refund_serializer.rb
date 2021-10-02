module Spree
  module Api
    module V2
      module Platform
        class RefundSerializer < BaseSerializer
          include ResourceSerializerConcern

          belongs_to :payment
          belongs_to :reimbursement
          belongs_to :refund_reason, object_method_name: :reason
          has_many :log_entries
        end
      end
    end
  end
end
