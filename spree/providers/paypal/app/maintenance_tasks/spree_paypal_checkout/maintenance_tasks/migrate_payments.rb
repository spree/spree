module SpreePaypalCheckout
  module MaintenanceTasks
    # Gives PayPal payments taken under the 5.x gem the 6.0 shape: the PayPal
    # order id as the response code, the key core links a session to its
    # payment by, and the capture id the 5.x gem stored there moved to
    # metadata['paypal_capture_id'], where refunds and the dashboard link read
    # it.
    #
    # The order id is found two ways, both from the 5.x gem's own records: the
    # session that took the payment holds the capture in its external data, and
    # a payment from the older non-session flow is matched through
    # spree_paypal_checkout_orders, which must therefore not be dropped first.
    # A payment matched by neither is logged and left as it was.
    class MigratePayments < Spree::MaintenanceTask
      LEGACY_ORDERS_TABLE = 'spree_paypal_checkout_orders'.freeze

      supports_dry_run

      def collection
        gateway_ids = Spree::PaymentMethod.unscoped.where(type: 'SpreePaypalCheckout::Gateway').select(:id)
        Spree::Payment.unscoped.where(payment_method_id: gateway_ids).where.not(response_code: [nil, '']).order(:id)
      end

      def process(payment)
        # Payments taken in 6.0, and those an earlier run converted, already
        # carry what PayPal issued.
        if payment.metadata['paypal_capture_id'].present? || payment.metadata['paypal_authorization_id'].present?
          return tally(:already_converted)
        end

        paypal_order_id = paypal_order_id_for(payment)
        if paypal_order_id.nil?
          Rails.logger.warn("[spree_paypal_checkout] migrate_paypal_payments: no PayPal order found for payment #{payment.id}")
          return tally(:unmatched)
        end
        return tally(:would_convert) if dry_run?

        payment.update_columns(
          response_code: paypal_order_id,
          metadata: payment.metadata.merge('paypal_capture_id' => payment.response_code),
          updated_at: Time.current
        )
        tally(:converted)
      rescue ActiveRecord::RecordNotUnique
        # Another payment of the same order already carries this PayPal order.
        Rails.logger.warn("[spree_paypal_checkout] migrate_paypal_payments: payment #{payment.id} duplicates another payment's PayPal order")
        tally(:unmatched)
      end

      private

      def paypal_order_id_for(payment)
        capture_id = payment.response_code
        session_order_id(payment, capture_id) || legacy_order_id(payment, capture_id)
      end

      # The 5.x session stored PayPal's whole capture response as its external
      # data, the order id as its external id.
      # Looked up within the payment's own order or cart, so each payment reads
      # a handful of rows.
      def session_order_id(payment, capture_id)
        owner = payment.order_id ? { order_id: payment.order_id } : { cart_id: payment.cart_id }
        return if owner.values.first.nil?

        sessions = Spree::PaymentSessions::PaypalCheckout.unscoped.where(payment_method_id: payment.payment_method_id, **owner)
        sessions.find { |session| capture_id_in(session.external_data) == capture_id }&.external_id
      end

      # The older flow only ever paid for orders.
      def legacy_order_id(payment, capture_id)
        return if payment.order_id.nil? || !legacy_orders_table?

        rows = legacy_order_model.where(payment_method_id: payment.payment_method_id, order_id: payment.order_id)
        rows.find { |row| capture_id_in(row.data) == capture_id }&.paypal_id
      end

      def capture_id_in(data)
        data = JSON.parse(data) if data.is_a?(String)
        return unless data.is_a?(Hash)

        data.dig('purchase_units', 0, 'payments', 'captures', 0, 'id')
      rescue JSON::ParserError
        nil
      end

      def legacy_orders_table?
        @legacy_orders_table = ActiveRecord::Base.connection.table_exists?(LEGACY_ORDERS_TABLE) if @legacy_orders_table.nil?
        @legacy_orders_table
      end

      # The 5.x model is gone, so the table is read through a throwaway one.
      def legacy_order_model
        @legacy_order_model ||= Class.new(ActiveRecord::Base) do
          self.table_name = LEGACY_ORDERS_TABLE
          self.inheritance_column = nil
        end
      end
    end
  end
end
