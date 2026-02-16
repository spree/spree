module Spree
  module Api
    module V3
      class CreditCardSerializer < BaseSerializer
        typelize cc_type: :string, last_digits: :string, month: :number, year: :number,
                 name: 'string | null', default: :boolean, gateway_payment_profile_id: 'string | null'

        attributes :cc_type, :last_digits, :month, :year, :name, :default, :gateway_payment_profile_id
      end
    end
  end
end
