module Spree
  module DeliveryProfiles
    # Physical goods — the default profile kind. Accepts any non-digital
    # provider (shipping, pickup, extension mechanics); the store's
    # "General" default profile is one of these.
    class Shipping < Spree::DeliveryProfile
      def accepts_provider?(provider_class)
        !provider_class.digital?
      end
    end
  end
end
