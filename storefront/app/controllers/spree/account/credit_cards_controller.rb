module Spree
  module Account
    class CreditCardsController < BaseController
      def index
        @user = try_spree_current_user
        @credit_cards = @user.credit_cards.order(created_at: :desc).page(params[:page]).per(25)
        @default_credit_card = @user.default_credit_card
      end

      def new
        @user = try_spree_current_user  
        @credit_card = Spree::CreditCard.new(user: @user)
        @stripe_setup_intent = SpreeStripe::CreateSetupIntent.call(gateway: current_store.stripe_gateway,
                                                                   user: @user,
                                                                   payment_methods: ['card'])
      end

      def create; end

      def destroy; end

      private

      def accurate_title
        Spree.t(:credit_cards)
      end
    end
  end
end
