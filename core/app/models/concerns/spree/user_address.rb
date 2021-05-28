module Spree
  module UserAddress
    extend ActiveSupport::Concern

    included do
      belongs_to :bill_address, foreign_key: :bill_address_id, class_name: 'Spree::Address',
                                optional: true
      alias_attribute :billing_address, :bill_address

      belongs_to :ship_address, foreign_key: :ship_address_id, class_name: 'Spree::Address',
                                optional: true
      alias_attribute :shipping_address, :ship_address

      accepts_nested_attributes_for :ship_address, :bill_address

      has_many :addresses, -> { where(deleted_at: nil).order('updated_at DESC') },
                           class_name: 'Spree::Address', foreign_key: :user_id

      validate :address_not_associated_with_other_user, :address_not_deprecated_in_completed_order

      def persist_order_address(order)
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
        errors.add(:bill_address_id, :belongs_to_other_user) if bill_address&.user_id && self != bill_address&.user
        errors.add(:ship_address_id, :belongs_to_other_user) if ship_address&.user_id && self != ship_address&.user
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
