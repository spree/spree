module Spree
  module Addresses
    module Helper
      private

      # Points the customer's default billing/shipping slots at an address.
      #
      # Writes the columns directly: both callers have already established
      # that the address is the customer's own — Create assigns the owner,
      # Update pins it from the record being edited — so the ownership
      # validation this skips cannot fail, and skipping it avoids re-running
      # the customer's whole validation set to move one foreign key. The
      # checkout path promotes defaults by plain assignment instead, because
      # there the address ownership is exactly what is still in question.
      def assign_to_user_as_default(user:, address_id:, default_billing: true, default_shipping: true)
        attributes_to_update = {
          ship_address_id: (address_id if default_shipping),
          bill_address_id: (address_id if default_billing),
        }.compact_blank

        user.update_columns(**attributes_to_update, updated_at: Time.current) if attributes_to_update.present?
      end
    end
  end
end
