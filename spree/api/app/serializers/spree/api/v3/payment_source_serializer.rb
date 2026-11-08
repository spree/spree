module Spree
  module Api
    module V3
      class PaymentSourceSerializer < BaseSerializer
        typelize gateway_payment_profile_id: [:string, nullable: true]

        attributes :gateway_payment_profile_id

        expandable_custom_fields
      end
    end
  end
end
