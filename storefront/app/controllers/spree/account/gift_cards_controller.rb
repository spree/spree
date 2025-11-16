module Spree
  module Account
    class GiftCardsController < BaseController
      def index
        @pagy, @gift_cards = pagy(@user.gift_cards.order(created_at: :desc), items: 25)
      end

      private

      def accurate_title
        Spree.t(:gift_cards)
      end
    end
  end
end
