module Spree
  module Admin
    module StoresHelper
      def selected_checkout_zone(store)
        store&.checkout_zone || Spree::Zone.default_checkout_zone
      end
    end
  end
end
