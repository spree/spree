module Spree
  module Account
    class GiftCardsController < BaseController
      def index
        @gift_cards = @user.gift_cards.order(created_at: :desc).page(params[:page]).per(25)
      end

      private

      def accurate_title
        Spree.t(:gift_cards)
      end
    end
  end
end
