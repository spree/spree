module Spree
  module Carts
    class Associate
      prepend Spree::ServiceModule::Base

      def call(guest_cart: nil, guest_order: nil, user: nil, override_email: true, guest_only: false)
        if guest_order
          Spree::Deprecation.warn('Calling Spree::Carts::Associate with guest_order: is deprecated and will be removed in Spree 6.1. Pass guest_cart: instead.')
          guest_cart ||= guest_order
        end
        return failure(guest_cart, 'Already assigned to a user') if guest_only && guest_cart.user.present? && guest_cart.user != user

        guest_cart.user           = user
        guest_cart.email          = user.email if override_email
        guest_cart.bill_address ||= user.bill_address
        guest_cart.ship_address ||= user.ship_address

        owner_key = guest_cart.is_a?(Spree::Cart) ? :customer_id : :user_id
        changes = {
          owner_key => guest_cart.user&.id,
          email: guest_cart.email,
          bill_address_id: guest_cart.bill_address&.id,
          ship_address_id: guest_cart.ship_address&.id
        }.compact

        # immediately persist the changes we just made, but don't use save
        # since we might have an invalid address associated
        ActiveRecord::Base.connected_to(role: :writing) do
          guest_cart.class.unscoped.where(id: guest_cart.id).update_all(changes)
        end

        # Manually publish the update event since update_all bypasses
        # callbacks — under the record's own prefix (cart.updated for carts).
        guest_cart.publish_event("#{guest_cart.event_prefix}.updated") if changes.present?

        success(guest_cart)
      end
    end
  end
end
