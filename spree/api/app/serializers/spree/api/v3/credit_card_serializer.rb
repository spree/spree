module Spree
  module Api
    module V3
      class CreditCardSerializer < BaseSerializer
        typelize brand: :string, last4: :string, month: :number, year: :number,
                 name: [:string, nullable: true], default: :boolean,
                 gateway_payment_profile_id: [:string, nullable: true]

        attributes :brand, :last4, :month, :year, :name, :default, :gateway_payment_profile_id
      end
    end
  end
end
