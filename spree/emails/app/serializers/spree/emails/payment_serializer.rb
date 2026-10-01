module Spree
  module Emails
    class PaymentSerializer < Spree::Api::V3::PaymentSerializer
      typelize source: ['Record<string, unknown>', nullable: true]

      one :payment_method, resource: Spree::Emails::PaymentMethodSerializer
    end
  end
end
