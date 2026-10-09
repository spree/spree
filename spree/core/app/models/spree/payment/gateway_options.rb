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
      delegate :email, :customer_id, to: :order
      # Stable handle for a gateway to find its own payment back. The derived
      # number cannot be queried (its column is NULL on 6.0 rows) and shifts
      # if an earlier sibling is destroyed — nothing durable may key on it.
      delegate :prefixed_id, to: :payment, prefix: true

      def statement_descriptor_suffix = order.number
      def customer = order.email
      def ip = order.last_ip_address
      # The payment number already names its order (`R1001-P1`), so this is
      # the payment number alone rather than the two concatenated.
      def order_id = payment.number
      def payment_id = payment.number

      # Built on the prefixed ID, not the number: a derived number shifts if
      # an earlier sibling payment is destroyed, and a shifted idempotency
      # key could collide with one already used at the gateway.
      def idempotency_key
        "spree-#{payment.prefixed_id}"
      end

      def shipping
        order.delivery_total * exchange_multiplier
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
        %i[email customer customer_id ip order_id payment_id payment_prefixed_id idempotency_key shipping tax
           subtotal discount currency billing_address shipping_address]
      end

      def to_hash
        hash_methods.index_with { |method| send(method) }
      end

      private

      def exchange_multiplier
        payment.payment_method.try(:exchange_multiplier) || 1
      end
    end
  end
end
