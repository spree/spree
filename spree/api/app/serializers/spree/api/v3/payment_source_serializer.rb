module Spree
  module Api
    module V3
      class PaymentSourceSerializer < BaseSerializer
        typelize gateway_payment_profile_id: [:string, nullable: true]

        attributes :gateway_payment_profile_id
      end
    end
  end
end
