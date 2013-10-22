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
          unless self.bill_address || self.ship_address
            self.bill_address = order.bill_address.clone
            self.ship_address = order.ship_address.clone
            self.save
          end
        end
      end
    end
  end
end
