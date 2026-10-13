module Spree
  module Emails
    class GiftCardSerializer < Spree::Api::V3::GiftCardSerializer
      without_display_money
    end
  end
end
