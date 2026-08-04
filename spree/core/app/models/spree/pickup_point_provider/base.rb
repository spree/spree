module Spree
  module PickupPointProvider
    # Contract for third-party pickup point networks (InPost lockers, DHL
    # ServicePoints, ...). Points are ephemeral value objects — never
    # persisted; the selected point is validated via +find_by_external_id+
    # and frozen into +fulfillment.pickup_point_data+.
    class Base
      # @return [Array<Spree::PickupPointOption>]
      def find_nearby(latitude:, longitude:, limit: 20)
        raise NotImplementedError, "Please implement 'find_nearby' in your pickup point provider: #{self.class.name}"
      end

      # @return [Spree::PickupPointOption, nil]
      def find_by_external_id(external_id)
        raise NotImplementedError, "Please implement 'find_by_external_id' in your pickup point provider: #{self.class.name}"
      end
    end
  end
end
