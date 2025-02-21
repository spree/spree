module Spree
  module Account
    class BaseController < Spree::StoreController
      before_action :require_user

      protected

      def accurate_title
        Spree.t(:my_account)
      end
    end
  end
end
