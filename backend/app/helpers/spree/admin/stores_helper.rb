module Spree
  module Admin
    module StoresHelper
      def selected_checkout_zone(store)
        return store.checkout_zone_id unless store.checkout_zone_id.nil?
        return checkout_zone_id('No Limits') if Spree::Config[:checkout_zone].nil?

        return checkout_zone_id(Spree::Config[:checkout_zone]) unless Spree::Config[:checkout_zone].nil?
      end

      private

      def checkout_zone_id(name)
        zone = Spree::Zone.find_by(name: name)
        zone.nil? ? 0 : zone.id
      end
    end
  end
end
