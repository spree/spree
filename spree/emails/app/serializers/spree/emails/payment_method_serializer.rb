module Spree
  module Emails
    class PaymentMethodSerializer < Spree::Api::V3::PaymentMethodSerializer
      _attributes.delete(:custom_fields)
      _attributes.delete(:public_preferences)
    end
  end
end
