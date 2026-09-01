module Spree
  module UserAddress
    extend ActiveSupport::Concern

    included do
      include Spree::HasAddressBook
      has_address_book bill: :bill_address_id, ship: :ship_address_id

      belongs_to :bill_address, foreign_key: :bill_address_id, class_name: 'Spree::Address',
                                optional: true
      alias_method :billing_address, :bill_address
      alias_method :billing_address=, :bill_address=

      belongs_to :ship_address, foreign_key: :ship_address_id, class_name: 'Spree::Address',
                                optional: true
      alias_method :shipping_address, :ship_address
      alias_method :shipping_address=, :ship_address=

      accepts_nested_attributes_for :ship_address, :bill_address

      has_many :addresses, -> { where(deleted_at: nil).order('updated_at DESC') },
                           class_name: 'Spree::Address', as: :owner

      validate :address_not_associated_with_other_user, :address_not_deprecated_in_completed_order

      def address
        @address ||= bill_address || ship_address || addresses.first
      end

      # @deprecated Nothing in Spree calls this. Checkout promotes the addresses
      #   it accepts to the customer's defaults on its own (see
      #   Spree::Purchase::Addresses), and a guest who registers after placing
      #   an order has that order's addresses adopted by Spree::Customers::Create.
      #   Removed in Spree 6.1.
      def persist_order_address(order)
        Spree::Deprecation.warn('Spree::UserAddress#persist_order_address is deprecated and will be removed in Spree 6.1. Checkout already promotes the addresses it accepts to the customer\'s defaults.')

        # FIXME: we should check if the User's address is associated with country accepted by Store
        # if not we should try to find an address with valid country in User's address book
        # or we should call `build_bill_address`
        b_address = bill_address || build_bill_address
        b_address.attributes = order.bill_address.value_attributes
        b_address.save
        update(bill_address_id: b_address.id)

        # May not be present if delivery step has been removed
        if order.ship_address
          s_address = ship_address || build_ship_address
          s_address.attributes = order.ship_address.value_attributes
          s_address.save
          update(ship_address_id: s_address.id)
        end
      end

      private

      def address_not_associated_with_other_user
        errors.add(:bill_address_id, :belongs_to_other_user) if bill_address&.owner && self != bill_address.owner
        errors.add(:ship_address_id, :belongs_to_other_user) if ship_address&.owner && self != ship_address.owner
      end

      def address_not_deprecated_in_completed_order
        errors.add(:bill_address_id, :deprecated_in_completed_order) if
          orders.complete.with_deleted_bill_address.where(bill_address: bill_address_id).any?
        errors.add(:ship_address_id, :deprecated_in_completed_order) if
          orders.complete.with_deleted_ship_address.where(ship_address: ship_address_id).any?
      end
    end
  end
end
