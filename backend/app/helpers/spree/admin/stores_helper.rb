module Spree
  module Admin
    module StoresHelper
      def selected_checkout_zone(store)
        return store.checkout_zone_id unless store.checkout_zone_id.nil?
        return checkout_zone('No Limits').id if Spree::Config[:checkout_zone].nil?

        return checkout_zone(Spree::Config[:checkout_zone]).id unless Spree::Config[:checkout_zone].nil?
      end

      private

      def checkout_zone(name)
        Spree::Zone.find_by(name: name)
      end
    end
  end
end
