module Spree
  module Cart
    class Associate
      prepend Spree::ServiceModule::Base

      def call(guest_order:, user:, override_email: true, guest_only: false)
        return failure(guest_order, 'Already assigned to a user') if guest_only && guest_order.user.present? && guest_order.user != user

        guest_order.user           = user
        guest_order.email          = user.email if override_email
        guest_order.bill_address ||= user.bill_address
        guest_order.ship_address ||= user.ship_address

        changes = guest_order.slice(*Spree::Order::ASSOCIATED_USER_ATTRIBUTES)

        # immediately persist the changes we just made, but don't use save
        # since we might have an invalid address associated
        ActiveRecord::Base.connected_to(role: :writing) do
          Spree::Order.unscoped.where(id: guest_order.id).update_all(changes)
        end

        # Manually publish update event since update_all bypasses callbacks
        guest_order.publish_event('order.updated') if changes.present?

        success(guest_order)
      end
    end
  end
end
