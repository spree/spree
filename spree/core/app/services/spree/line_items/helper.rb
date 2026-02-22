module Spree
  module LineItems
    module Helper
      protected

      def recalculate_service
        Spree.cart_recalculate_service
      end
    end
  end
end
