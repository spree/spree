module Spree
  module Addresses
    module Helper
      private

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
