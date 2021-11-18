module Spree
  module V2
    module Storefront
      class PaymentMethodSerializer < BaseSerializer
        set_type :payment_method

        attributes :type, :name, :description, :public_metadata

        attribute :preferences do |object|
          object.public_preferences.as_json
        end
      end
    end
  end
end
