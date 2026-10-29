module Spree
  module Emails
    class PaymentMethodSerializer < Spree::Api::V3::PaymentMethodSerializer
      _attributes.delete(:custom_fields)
    end
  end
end
