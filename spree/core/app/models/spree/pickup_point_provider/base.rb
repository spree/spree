module Spree
  module PickupPointProvider
    # Contract for third-party pickup point networks (InPost lockers, DHL
    # ServicePoints, ...). Points are ephemeral value objects — never
    # persisted; the selected point is validated via +find_by_external_id+
    # and frozen into +fulfillment.pickup_point_data+.
    #
    # Not yet a stable extension point: in 6.1 the constructor becomes
    # +new(delivery_method)+ (credential access via the method's store
    # integrations) and +find_nearby+ gains +zipcode:+/+query:+ params.
    # Build third-party providers against 6.1, not this shape.
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
