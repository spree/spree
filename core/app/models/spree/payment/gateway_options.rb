module Spree
  class Payment < Spree::Base
    class GatewayOptions
      def initialize(payment)
        @payment = payment
      end

      def email
        order.email
      end

      def customer
        order.email
      end

      def customer_id
        order.user_id
      end

      def ip
        order.last_ip_address
      end

      def order_id
        "#{order.number}-#{@payment.number}"
      end

      def shipping
        order.ship_total * exchange_multiplier
      end

      def tax
        order.additional_tax_total * exchange_multiplier
      end

      def subtotal
        order.item_total * exchange_multiplier
      end

      def discount
        order.promo_total * exchange_multiplier
      end

      def currency
        @payment.currency
      end

      def billing_address
        order.bill_address.try(:active_merchant_hash)
      end

      def shipping_address
        order.ship_address.try(:active_merchant_hash)
      end

      def hash_methods
        [
          :email,
          :customer,
          :customer_id,
          :ip,
          :order_id,
          :shipping,
          :tax,
          :subtotal,
          :discount,
          :currency,
          :billing_address,
          :shipping_address
        ]
      end

      def to_hash
        Hash[hash_methods.map do |method|
          [method, send(method)]
        end]
      end

      private

      def order
        @payment.order
      end

      def exchange_multiplier
        @payment.payment_method.try(:exchange_multiplier) || 1.0
      end
    end
  end
end
