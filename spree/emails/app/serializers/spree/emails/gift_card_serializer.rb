module Spree
  module Emails
    class GiftCardSerializer < Spree::Api::V3::GiftCardSerializer
      _attributes.delete(:custom_fields)

      without_display_money
    end
  end
end
