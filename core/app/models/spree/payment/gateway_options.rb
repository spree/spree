module Spree
  class Payment < Spree::Base
    class GatewayOptions
      def initialize(payment)
        @payment = payment
      end

      def email
        @email ||= order.email
      end

      def customer
        @customer ||= order.email
      end

      def customer_id
        @customer_id ||= order.user_id
      end

      def ip
        @ip ||= order.last_ip_address
      end

      def order_id
        @order_id ||= "#{order.number}-#{@payment.number}"
      end

      def shipping
        @shipping ||= order.ship_total * exchange_multiplier
      end

      def tax
        @tax ||= order.additional_tax_total * exchange_multiplier
      end

      def subtotal
        @subtotal ||= order.item_total * exchange_multiplier
      end

      def discount
        @discount ||= order.promo_total * exchange_multiplier
      end

      def currency
        @currency ||= @payment.currency
      end

      def billing_address
        @billing_address ||= order.bill_address.try(:active_merchant_hash)
      end

      def shipping_address
        @shipping_address ||= order.ship_address.try(:active_merchant_hash)
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
        @order ||= @payment.order
      end

      def exchange_multiplier
        @exchange_multiplier ||= @payment.payment_method.try(:exchange_multiplier) || 1.0
      end
    end
  end
end
