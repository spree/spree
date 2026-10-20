module Spree
  module Emails
    class FeeSerializer < Spree::Api::V3::FeeSerializer
      without_display_money
    end
  end
end
