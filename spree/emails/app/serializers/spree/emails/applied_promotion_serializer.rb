module Spree
  module Emails
    class AppliedPromotionSerializer < Spree::Api::V3::AppliedPromotionSerializer
      without_display_money
    end
  end
end
