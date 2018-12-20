module Spree
  module V2
    module Storefront
      class PaymentMethodSerializer < BaseSerializer
        set_type :payment_method

        attributes :type, :name, :description
      end
    end
  end
end
