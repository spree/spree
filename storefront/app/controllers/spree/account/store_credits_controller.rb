module Spree
  module Account
    class StoreCreditsController < BaseController
      def index
        @store_credit_events = Spree::StoreCreditEvent.where(store_credit: user_store_credits).
                               exposed_events.
                               reverse_chronological.
                               page(params[:page]).per(25)
      end

      private

      def accurate_title
        Spree.t(:store_credit_name)
      end

      def user_store_credits
        try_spree_current_user.store_credits
      end
    end
  end
end
