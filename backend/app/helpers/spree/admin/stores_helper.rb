module Spree
  module Admin
    module StoresHelper
      def selected_checkout_zone(store)
        return Spree::Zone.find_by(id: store.checkout_zone_id) unless store.checkout_zone_id.nil?

        Spree::Zone.default_checkout_zone
      end
    end
  end
end
