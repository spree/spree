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
          address = self.bill_address || self.build_bill_address
          address.attributes = order.bill_address.attributes.except('id', 'updated_at', 'created_at')
          address.save

          address = self.ship_address || self.build_ship_address
          address.attributes = order.ship_address.attributes.except('id', 'updated_at', 'created_at')
          address.save
        end
      end
    end
  end
end
