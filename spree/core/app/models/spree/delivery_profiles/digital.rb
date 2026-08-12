module Spree
  module DeliveryProfiles
    # Digital goods: products in this profile are delivered digitally and
    # checkout collects no shipping address. Only digital-provider methods
    # may join, so the profile can never quietly reinterpret its products.
    class Digital < Spree::DeliveryProfile
      def accepts_provider?(provider_class)
        provider_class.digital?
      end

      def digital?
        true
      end

      def requires_shipping_address?
        false
      end
    end
  end
end
