# https://github.com/spree-contrib/spree_address_book/blob/master/app/models/spree/order_decorator.rb
module Spree
  class Order < Spree::Base
    module AddressBook
      extend ActiveSupport::Concern

      def clone_shipping_address
        if ship_address
          self.bill_address = ship_address
        end
        true
      end

      def clone_billing_address
        if bill_address
          self.ship_address = bill_address
        end
        true
      end

      def bill_address_id=(id)
        address = Spree::Address.find_by(id: id)
        if address && address.user_id == user_id
          self['bill_address_id'] = address.id
          user.update_attribute(:bill_address_id, address.id)
          bill_address.reload
        else
          self['bill_address_id'] = nil
        end
      end

      def bill_address_attributes=(attributes)
        self.bill_address = update_or_create_address(attributes)
        user.bill_address = bill_address if user
      end

      def ship_address_id=(id)
        address = Spree::Address.find_by(id: id)
        if address && address.user_id == user_id
          self['ship_address_id'] = address.id
          user.update_attribute(:ship_address_id, address.id)
          ship_address.reload
        else
          self['ship_address_id'] = nil
        end
      end

      def ship_address_attributes=(attributes)
        self.ship_address = update_or_create_address(attributes)
        user.ship_address = ship_address if user
      end

      private

      def update_or_create_address(attributes = {})
        return if attributes.blank?

        attributes.transform_values! { |v| v == '' ? nil : v }

        default_address_scope = user ? user.addresses : ::Spree::Address
        default_address = default_address_scope.find_by(id: attributes[:id])

        if default_address&.editable?
          default_address.update(attributes)

          return default_address
        end

        ::Spree::Address.find_or_create_by(attributes.except(:id, :updated_at, :created_at))
      end
    end
  end
end
