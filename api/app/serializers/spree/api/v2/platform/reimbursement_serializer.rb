module Spree
  module Api
    module V2
      module Platform
        class ReimbursementSerializer < BaseSerializer
          include ResourceSerializerConcern

          belongs_to :order
          belongs_to :customer_return

          has_many :refunds
          has_many :reimbursement_credits, object_method_name: :credits, id_method_name: :credit_ids
          has_many :return_items
        end
      end
    end
  end
end
