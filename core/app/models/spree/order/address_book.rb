module Spree
  class Order < Spree.base_class
    module AddressBook
      def clone_shipping_address
        self.bill_address_id = ship_address_id if ship_address_id
        true
      end

      def clone_billing_address
        self.ship_address_id = bill_address_id if bill_address_id
        true
      end

      def bill_address_id=(id)
        address = Spree::Address.find_by(id: id)
        if address && address.user_id == user_id
          self['bill_address_id'] = address.id
          bill_address.reload
        else
          self['bill_address_id'] = nil
        end
      end

      def bill_address_attributes=(attributes)
        self.bill_address = update_or_create_address(attributes)

        if should_assign_user_default_address?(bill_address)
          user_old_address = user&.bill_address
          user_old_address&.delete unless user_old_address&.valid?
          user&.update(bill_address: bill_address)
        end
      end

      def ship_address_id=(id)
        address = Spree::Address.find_by(id: id)
        if address && address.user_id == user_id
          self['ship_address_id'] = address.id
          ship_address.reload
        else
          self['ship_address_id'] = nil
        end
      end

      def ship_address_attributes=(attributes)
        self.ship_address = update_or_create_address(attributes)

        if should_assign_user_default_address?(ship_address)
          user_old_address = user&.ship_address
          user_old_address&.delete unless user_old_address&.valid?
          user&.update(ship_address: ship_address)
        end
      end

      private

      def update_or_create_address(attributes = {})
        return if attributes.blank?

        attributes.transform_values!(&:presence)
        attributes = attributes.to_h.symbolize_keys

        default_address_scope = user ? user.addresses : ::Spree::Address.where(user_id: nil)
        default_address = default_address_scope.find_by(id: attributes[:id])

        if default_address&.editable?
          default_address.update(attributes)

          return default_address
        end

        attributes = attributes.except(:id, :updated_at, :created_at)
        attributes[:user_id] = user&.id

        existing_address = find_existing_address(attributes)
        return existing_address if existing_address

        ::Spree::Address.create(attributes)
      end

      def find_existing_address(attributes)
        address_attributes = attributes.except(:firstname, :state_name)
        state_name = attributes[:state_name]

        scope = Spree::Address.not_deleted.where(address_attributes)
        scope = scope.by_state_name_or_abbr(state_name) if state_name.present?
        scope.first
      end

      def should_assign_user_default_address?(address)
        address.present? && address.valid?
      end
    end
  end
end
