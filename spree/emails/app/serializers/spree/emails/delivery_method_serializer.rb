module Spree
  module Emails
    class DeliveryMethodSerializer < Spree::Api::V3::DeliveryMethodSerializer
      _attributes.delete(:custom_fields)
    end
  end
end
