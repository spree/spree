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

        attributes = attributes.select { |_k, v| v.present? }

        if user
          address = user.addresses.build(attributes.except(:id)).check
          return address if address.id
        end

        if attributes[:id]
          address = Spree::Address.find(attributes[:id])
          attributes.delete(:id)

          if address&.editable?
            address.update(attributes)
            return address
          else
            attributes.delete(:id)
          end
        end

        unless attributes[:id]
          address = Spree::Address.new(attributes)
          address.save
        end

        address
      end
    end
  end
end
