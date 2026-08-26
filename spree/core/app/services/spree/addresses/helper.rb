module Spree
  module Addresses
    module Helper
      private

      # Points an owner's default billing/shipping slots at an address.
      #
      # Which columns those are is the owner's business — a customer and a
      # company node name them differently — so the owner is asked rather
      # than assumed. The checkout path promotes defaults by plain assignment
      # instead, because there the address ownership is exactly what is still
      # in question.
      #
      # @param owner [Object, nil] anything including Spree::HasAddressBook
      def assign_owner_default(owner:, address_id:, default_billing: true, default_shipping: true)
        return if owner.nil? || !owner.respond_to?(:assign_default_address)

        owner.assign_default_address(
          address_id: address_id,
          billing: default_billing,
          shipping: default_shipping
        )
      end
    end
  end
end
