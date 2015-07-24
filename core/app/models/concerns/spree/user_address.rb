module Spree
  module UserAddress
    extend ActiveSupport::Concern

    ATTRIBUTE_BLACKLIST = IceNine.deep_freeze(%w[id updated_at created_at])

    included do
      belongs_to :bill_address, foreign_key: :bill_address_id, class_name: 'Spree::Address'
      alias_attribute :billing_address, :bill_address

      belongs_to :ship_address, foreign_key: :ship_address_id, class_name: 'Spree::Address'
      alias_attribute :shipping_address, :ship_address

      accepts_nested_attributes_for :ship_address, :bill_address

      def persist_order_address(order)
        %i[bill_address ship_address].each do |association|
          order_address = order.public_send(association)
          next unless order_address
          address = public_send(association) || Address.default
          address.update_attributes!(
            order_address.attributes.except(*ATTRIBUTE_BLACKLIST)
          )
          update_attributes!(association => address)
        end
      end
    end
  end
end
