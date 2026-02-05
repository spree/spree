module Spree
  class Order < Spree.base_class
    module AddressBook
      def clone_shipping_address
        self.bill_address = ship_address if ship_address
        user.bill_address = ship_address if should_assign_user_default_address?(ship_address)
        true
      end

      def clone_billing_address
        self.ship_address = bill_address if bill_address
        user.ship_address = bill_address if should_assign_user_default_address?(bill_address)
        true
      end

      def bill_address_id=(id)
        return if bill_address_id == id

        address = Spree::Address.find_by(id: id)
        # rubocop:disable Style/ConditionalAssignment
        if address && user_id.present? && address.user_id == user_id
          self['bill_address_id'] = address.id
        else
          self['bill_address_id'] = nil
        end
        # rubocop:enable Style/ConditionalAssignment
        reset_bill_address
      end

      def bill_address_attributes=(attributes)
        self.bill_address = update_or_create_address(attributes)
        user.bill_address = bill_address if should_assign_user_default_address?(bill_address)
      end

      def ship_address_id=(id)
        return if ship_address_id == id

        address = Spree::Address.find_by(id: id)
        # rubocop:disable Style/ConditionalAssignment
        if address && user_id.present? && address.user_id == user_id
          self['ship_address_id'] = address.id
        else
          self['ship_address_id'] = nil
        end
        # rubocop:enable Style/ConditionalAssignment
        reset_ship_address
      end

      def ship_address_attributes=(attributes)
        self.ship_address = update_or_create_address(attributes)
        user.ship_address = ship_address if should_assign_user_default_address?(ship_address)
        self.ship_address = nil if quick_checkout_address?(attributes[:quick_checkout]) && !ship_address.persisted?
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
        address_attributes = attributes.except(:state_name)
        state_name = attributes[:state_name]

        scope = Spree::Address.not_deleted.where(address_attributes)
        scope = scope.by_state_name_or_abbr(state_name) if state_name.present?
        scope.first
      end

      def quick_checkout_address?(quick_checkout_param)
        quick_checkout_param.present? ? quick_checkout_param.to_b : false
      end

      def should_assign_user_default_address?(address)
        user.present? && address.present? && address.valid? && address.user == user && !address.quick_checkout?
      end
    end
  end
end
