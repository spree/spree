module Spree
  class Payment < Spree.base_class
    class GatewayOptions
      def initialize(payment)
        @payment = payment
        # The payment's cart or order — the reader keeps the legacy `order`
        # name because gateway extensions subclass this class.
        @order = payment.owner
      end

      attr_reader :payment, :order
      delegate :currency, to: :payment
      delegate :email, to: :order

      def statement_descriptor_suffix
        order.number
      end

      def customer
        order.email
      end

      def customer_id
        order.customer_id
      end

      def ip
        order.last_ip_address
      end

      # The payment number already names its order (`R1001-P1`), so this is
      # the payment number alone rather than the two concatenated.
      def order_id
        payment.number
      end

      def payment_id
        payment.number
      end

      # Built on the prefixed ID, not the number: a derived number shifts if
      # an earlier sibling payment is destroyed, and a shifted idempotency
      # key could collide with one already used at the gateway.
      def idempotency_key
        "spree-#{payment.prefixed_id}"
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
        order.discount_total * exchange_multiplier
      end

      def billing_address
        order.bill_address.try(:gateway_hash)
      end

      def shipping_address
        order.ship_address.try(:gateway_hash)
      end

      def hash_methods
        [
          :email,
          :customer,
          :customer_id,
          :ip,
          :order_id,
          :payment_id,
          :idempotency_key,
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
        payment.payment_method.try(:exchange_multiplier) || 1.0
      end
    end
  end
end
