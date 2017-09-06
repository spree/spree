module Spree
  class Payment
    class GatewayOptions
      attr_reader :payment

      def initialize(payment)
        @payment = payment
      end

      delegate :currency,
               :order, to: :payment, allow_nil: true

      delegate :additional_tax_total,
               :bill_address,
               :ship_address,
               :email,
               :item_total,
               :last_ip_address,
               :promo_total,
               :ship_total,
               :user_id, to: :order, allow_nil: true

      def customer
        email
      end

      def customer_id
        user_id
      end

      def ip
        last_ip_address
      end

      def order_id
        "#{order.number}-#{@payment.number}"
      end

      def shipping
        ship_total * exchange_multiplier
      end

      def tax
        additional_tax_total * exchange_multiplier
      end

      def subtotal
        item_total * exchange_multiplier
      end

      def discount
        promo_total * exchange_multiplier
      end

      def billing_address
        bill_address.try(:active_merchant_hash)
      end

      def shipping_address
        ship_address.try(:active_merchant_hash)
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

      def exchange_multiplier
        @payment.payment_method.try(:exchange_multiplier) || 1.0
      end
    end
  end
end
