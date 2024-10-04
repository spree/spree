module Spree
  module Api
    module V2
      module Platform
        class PaymentSourceSerializer < BaseSerializer
          belongs_to :payment_method
          belongs_to :user
        end
      end
    end
  end
end
