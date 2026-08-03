module Spree
  module Carts
    class Associate
      prepend Spree::ServiceModule::Base

      def call(guest_cart: nil, guest_order: nil, customer: nil, user: nil, override_email: true, guest_only: false)
        if guest_order
          Spree::Deprecation.warn('Calling Spree::Carts::Associate with guest_order: is deprecated and will be removed in Spree 6.1. Pass guest_cart: instead.')
          guest_cart ||= guest_order
        end
        if user && customer.nil?
          Spree::Deprecation.warn('Calling Spree::Carts::Associate with user: is deprecated and will be removed in Spree 6.1. Pass customer: instead.')
          customer = user
        end
        return failure(guest_cart, 'Already assigned to a customer') if guest_only && guest_cart.customer.present? && guest_cart.customer != customer

        guest_cart.customer       = customer
        guest_cart.email          = customer.email if override_email
        # Only valid saved defaults are copied — update_all below skips
        # validations, so a broken address-book entry must not land on the
        # cart. Digital-only checkouts never receive a ship address.
        guest_cart.bill_address ||= customer.bill_address if customer.bill_address&.valid?
        guest_cart.ship_address ||= customer.ship_address if customer.ship_address&.valid? && guest_cart.delivery_step_required?

        changes = {
          customer_id: guest_cart.customer&.id,
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
