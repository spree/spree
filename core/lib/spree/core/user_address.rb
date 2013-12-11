module Spree
  module Core
    module UserAddress
      extend ActiveSupport::Concern

      included do
        belongs_to :bill_address, foreign_key: :bill_address_id, class_name: 'Spree::Address'
        alias_attribute :billing_address, :bill_address

        belongs_to :ship_address, foreign_key: :ship_address_id, class_name: 'Spree::Address'
        alias_attribute :shipping_address, :ship_address

        def persist_order_address(order)
          b_address = self.bill_address || self.build_bill_address
          b_address.attributes = order.bill_address.attributes.except('id', 'updated_at', 'created_at')
          b_address.save
          self.update_attributes(bill_address_id: b_address.id)

          # May not be present if delivery step has been removed
          if order.ship_address
            s_address = self.ship_address || self.build_ship_address
            s_address.attributes = order.ship_address.attributes.except('id', 'updated_at', 'created_at')
            s_address.save
            self.update_attributes(ship_address_id: s_address.id)
          end
        end
      end
    end
  end
end