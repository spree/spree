module Spree
  module Account
    class GiftCardsController < BaseController
      def index
        @gift_cards = paginate_collection(@user.gift_cards.order(created_at: :desc), limit: 25)
      end

      private

      def accurate_title
        Spree.t(:gift_cards)
      end
    end
  end
end
