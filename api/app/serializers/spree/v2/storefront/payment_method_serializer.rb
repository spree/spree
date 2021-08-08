module Spree
  module V2
    module Storefront
      class PaymentMethodSerializer < BaseSerializer
        set_type :payment_method

        attributes :type, :name, :description

        attribute :preferences do |payment_method|
          {
            intents: payment_method.preferences[:intents],
            publishable_key: payment_method.preferences[:publishable_key],
            server: payment_method.preferences[:server],
            test_mode: payment_method.preferences[:test_mode]
          }
        end
      end
    end
  end
end
