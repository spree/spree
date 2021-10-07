module Spree
  module LineItems
    module Helper
      protected

      def recalculate_service
        Spree::Dependencies.cart_recalculate_service.constantize
      end
    end
  end
end
