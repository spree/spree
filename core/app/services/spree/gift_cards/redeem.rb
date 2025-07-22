module Spree
  module GiftCards
    class Redeem
      prepend Spree::ServiceModule::Base

      def call(gift_card:)
        if gift_card.amount_remaining.zero?
          gift_card.redeem!
        else
          gift_card.partial_redeem!
        end

        success(gift_card)
      end
    end
  end
end
