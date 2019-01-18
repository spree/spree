module Spree
  module V2
    module Storefront
      class CreditCardSerializer < BaseSerializer
        set_type :credit_card

        attributes :cc_type, :last_digits, :month, :year, :name

        belongs_to :payment_method,
                   serializer: Spree::V2::Storefront::PaymentMethodSerializer
      end
    end
  end
end
