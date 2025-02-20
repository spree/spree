module Spree
  module Account
    class BaseController < Spree::UsersController
      protected

      def accurate_title
        Spree.t(:my_account)
      end
    end
  end
end
