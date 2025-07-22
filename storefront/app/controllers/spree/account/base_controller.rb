module Spree
  module Account
    class BaseController < Spree::StoreController
      before_action :require_user
      before_action :set_user

      protected

      def accurate_title
        Spree.t(:my_account)
      end

      private

      def set_user
        @user = try_spree_current_user
      end
    end
  end
end
