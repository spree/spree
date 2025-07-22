module Spree
  module V2
    module Storefront
      class PaymentSourceSerializer < BaseSerializer
        belongs_to :payment_method
        belongs_to :user
      end
    end
  end
end
