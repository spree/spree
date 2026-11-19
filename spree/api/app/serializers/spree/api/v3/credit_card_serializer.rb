module Spree
  module Api
    module V3
      class CreditCardSerializer < BaseSerializer
        typelize brand: :string, last4: :string, month: :number, year: :number,
                 name: [:string, nullable: true], default: :boolean,
                 gateway_payment_profile_id: [:string, nullable: true],
                 # Null when that payment method was deleted since.
                 payment_method_id: [:string, nullable: true, comment: 'The payment method the card was saved with; a card is offered only for it.']

        attributes :brand, :last4, :month, :year, :name, :default, :gateway_payment_profile_id

        prefixed_id_attributes :payment_method

        expandable_custom_fields
      end
    end
  end
end
