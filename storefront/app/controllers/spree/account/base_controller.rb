module Spree
  module Account
    class BaseController < Spree::StoreController
      protected

      def accurate_title
        Spree.t(:my_account)
      end
    end
  end
end
