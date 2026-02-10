module Spree
  module Api
    module V3
      class CreditCardSerializer < BaseSerializer
        typelize cc_type: :string, last_digits: :string, month: :number, year: :number,
                 name: 'string | null', default: :boolean

        attributes :cc_type, :last_digits, :month, :year, :name, :default
      end
    end
  end
end
