module Spree
  module Api
    module V3
      class PaymentSourceSerializer < BaseSerializer
        typelize gateway_payment_profile_id: 'string | null',
                 public_metadata: 'Record<string, unknown> | null'

        attribute :gateway_payment_profile_id do |source|
          source.try(:gateway_payment_profile_id)
        end

        attribute :public_metadata do |source|
          source.try(:public_metadata)
        end
      end
    end
  end
end
