module Spree
  module Api
    module V2
      module Platform
        class CheckSerializer < BaseSerializer
          set_type :payment

          attributes :amount, :display_amount

          belongs_to :order
          belongs_to :payment_method
        end
      end
    end
  end
end
