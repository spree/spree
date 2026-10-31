module SpreePaypalCheckout
  class Gateway < ::Spree::Gateway
    # A PayPal payment session is a PayPal order. Creating the session creates
    # the order, the buyer approves it in PayPal's window, and completing the
    # session captures or authorizes it. Until then the order is inert: nothing
    # but this server can take money against it.
    module PaymentSessions
      extend ActiveSupport::Concern

      # Written by the gem; a client's values for them are ignored.
      OWNED_EXTERNAL_DATA_KEYS = %w[client_id intent attempt paypal_result].freeze
      # The buyer's card or account was refused and PayPal lets them pick
      # another in the same window, so the session stays open for them.
      RECOVERABLE_DECLINE = 'INSTRUMENT_DECLINED'.freeze
      # Answers that say nothing about the order: PayPal turned the request away
      # before looking, or could not be reached at all.
      RETRYABLE_STATUS_CODES = [401, 408, 429].freeze

      # Opens a new session on every call, canceling the cart's open PayPal
      # sessions first so only one order can ever be paid.
      #
      # @param order [Spree::Cart, Spree::Order]
      # @return [Spree::PaymentSessions::PaypalCheckout]
      # @raise [Spree::Core::GatewayError] for a zero amount, an amount PayPal
      #   cannot take, or a cart this method has already been paid for
      def create_payment_session(order:, amount: nil, external_data: {})
        total = amount.present? ? BigDecimal(amount.to_s) : order.total_minus_store_credits
        raise Spree::Core::GatewayError, I18n.t('spree.paypal_checkout.payment_session_errors.zero_amount') unless total.positive?

        SpreePaypalCheckout::Amounts.to_paypal(total, order.currency)
        replace_open_sessions(order)

        intent = paypal_intent
        presenter = SpreePaypalCheckout::OrderPresenter.new(order: order, amount: total, intent: intent)
        paypal_order = protect_from_error { create_paypal_order(presenter.order_request) }

        payment_session_class.create!(
          owner: order,
          payment_method: self,
          amount: total,
          currency: order.currency,
          status: 'pending',
          external_id: paypal_order['id'],
          customer: order.customer,
          # The JS SDK must load with the client id that created the order and
          # the order's own intent, or PayPal's buttons refuse it.
          external_data: client_external_data(external_data).merge(
            'client_id' => preferred_client_id,
            'intent' => intent
          )
        )
      end

      # A new amount is sent to PayPal before the session takes it, so PayPal
      # never captures a total Spree no longer charges. The whole purchase unit
      # is replaced: items and breakdown come and go with whether they add up.
      def update_payment_session(payment_session:, amount: nil, external_data: {})
        attrs = {}

        new_amount = BigDecimal(amount.to_s) if amount.present?
        if new_amount && new_amount != payment_session.amount
          presenter = SpreePaypalCheckout::OrderPresenter.new(
            order: payment_session.owner, amount: new_amount, intent: payment_session.intent || paypal_intent
          )
          protect_from_error { patch_paypal_order(payment_session.external_id, presenter.purchase_unit) }
          attrs[:amount] = new_amount
        end

        data = client_external_data(external_data)
        attrs[:external_data] = (payment_session.external_data || {}).merge(data) if data.any?

        payment_session.update!(attrs) if attrs.any?
      end

      # Captures or authorizes the order the buyer approved, then settles the
      # payment. Does NOT complete the cart: the storefront's cart-complete
      # call or the webhook handler does that.
      #
      # @raise [Spree::Core::GatewayError] when the session is not open, or
      #   PayPal declines; a recoverable decline leaves the session open
      def complete_payment_session(payment_session:, params: {})
        unless payment_session.pending? || payment_session.processing?
          raise Spree::Core::GatewayError, I18n.t('spree.paypal_checkout.payment_session_errors.not_open')
        end

        paypal_order = protect_from_error { paypal_order(payment_session.external_id) }

        # A capture that timed out may have gone through; it is settled, not
        # taken again.
        unless money_moved?(paypal_order)
          unless order_matches_session?(paypal_order, payment_session)
            payment_session.fail if payment_session.can_fail?
            return payment_session
          end

          paypal_order = move_money(payment_session)
        end

        settle(payment_session, paypal_order)
      end

      # A session that never reached Complete is canceled here alone: its order
      # can only ever be paid by this server. Otherwise the order is read,
      # since a capture that timed out may have gone through.
      #
      # @return [Boolean] whether the session was canceled
      # @raise [Spree::Core::GatewayError] when PayPal has taken the money
      # @raise [StandardError] PayPal's own error when it could not be asked
      def cancel_payment_session(payment_session:)
        return payment_session.cancel unless payment_session.complete_attempted?

        paypal_order = paypal_order(payment_session.external_id)

        if capture_taken?(paypal_order)
          raise Spree::Core::GatewayError, I18n.t('spree.paypal_checkout.payment_session_errors.payment_captured')
        end

        authorization = open_authorization(paypal_order)
        void_authorization(authorization['id'], request_id: "#{payment_session.prefixed_id}-void") if authorization

        payment_session.cancel
      rescue PaypalServerSdk::ErrorException => e
        raise if retryable_paypal_error?(e)
        # An order the account the credentials now reach does not know can no
        # longer be paid.
        return payment_session.cancel if e.response_code == 404

        raise Spree::Core::GatewayError, paypal_error_message(e)
      end

      # @return [Hash] the created order
      def create_paypal_order(order_request)
        client.orders.create_order('body' => order_request, 'prefer' => 'return=minimal').data.to_hash
      end

      def patch_paypal_order(paypal_order_id, purchase_unit)
        client.orders.patch_order(
          'id' => paypal_order_id,
          'body' => [
            PaypalServerSdk::Patch.new(
              op: PaypalServerSdk::PatchOp::REPLACE,
              path: "/purchase_units/@reference_id=='default'",
              value: purchase_unit.to_hash
            )
          ]
        )
      end

      # @return [Hash] the order, with its capture
      def capture_paypal_order(paypal_order_id, request_id:)
        client.orders.capture_order(
          'id' => paypal_order_id,
          'paypal_request_id' => request_id,
          'prefer' => 'return=representation'
        ).data.to_hash
      end

      # @return [Hash] the order, with its authorization
      def authorize_paypal_order(paypal_order_id, request_id:)
        client.orders.authorize_order(
          'id' => paypal_order_id,
          'paypal_request_id' => request_id,
          'prefer' => 'return=representation'
        ).data.to_hash
      end

      private

      # The attempt is stored before PayPal is asked, so a cancel after a
      # timeout knows to look at the order, and a retry of the same attempt
      # reaches PayPal as the same request.
      def move_money(payment_session)
        attempt = payment_session.attempt
        payment_session.update!(external_data: payment_session.external_data.merge('attempt' => attempt))
        action = payment_session.intent == PaypalServerSdk::CheckoutPaymentIntent::AUTHORIZE ? 'authorize' : 'capture'
        request_id = "#{payment_session.prefixed_id}-#{action}-#{attempt}"

        paypal_order = protect_from_error(money_moving: true) do
          action == 'authorize' ? authorize_paypal_order(payment_session.external_id, request_id: request_id) : capture_paypal_order(payment_session.external_id, request_id: request_id)
        end
        return paypal_order if money_moved?(paypal_order)

        payment_session.fail if payment_session.can_fail?
        status = payment_status(paypal_order)
        raise PaypalError.new(I18n.t('spree.paypal_checkout.payment_session_errors.declined', status: status), issue: status)
      rescue PaypalError => e
        if e.issue == RECOVERABLE_DECLINE
          payment_session.update!(external_data: payment_session.external_data.merge('attempt' => attempt + 1))
        elsif !e.status.to_i.in?(RETRYABLE_STATUS_CODES) && payment_session.reload.can_fail?
          # A rate limit or a refused token is not a decline: the buyer can
          # complete the same session again.
          payment_session.fail
        end
        raise
      end

      # Once money has moved the session is never failed: a failed session
      # lets the storefront open another and charge again.
      def settle(payment_session, paypal_order)
        payment_session.paypal_order = paypal_order
        payment_session.update!(
          external_data: payment_session.external_data.merge('paypal_result' => paypal_result(paypal_order))
        )
        report_amount_mismatch(payment_session, paypal_order)

        payment_session.process if payment_session.can_process?
        capture = captures(paypal_order).first
        payment_session.settle_payment!(captured: capture.present? && capture['status'] == 'COMPLETED')
        payment_session.complete unless payment_session.completed?
        payment_session
      end

      def order_matches_session?(paypal_order, payment_session)
        amount_matches?(Array(paypal_order['purchase_units']).first&.dig('amount'), payment_session.amount, payment_session.currency)
      end

      def report_amount_mismatch(payment_session, paypal_order)
        moved = first_payment(paypal_order)
        return if moved.nil? || amount_matches?(moved['amount'], payment_session.amount, payment_session.currency)

        expected = SpreePaypalCheckout::Amounts.to_paypal(payment_session.amount, payment_session.currency)

        Rails.error.report(
          Spree::Core::GatewayError.new(
            "PayPal took #{moved.dig('amount', 'value')} #{moved.dig('amount', 'currency_code')} " \
            "for a session of #{expected} #{payment_session.currency.upcase}"
          ),
          context: { payment_session_id: payment_session.id, paypal_order_id: payment_session.external_id },
          source: 'spree_paypal_checkout.complete_payment_session'
        )
      end

      def paypal_result(paypal_order)
        capture = captures(paypal_order).first
        authorization = authorizations(paypal_order).first
        {
          'status' => paypal_order['status'],
          'capture_id' => capture&.dig('id'),
          'capture_status' => capture&.dig('status'),
          'authorization_id' => authorization&.dig('id'),
          'authorization_status' => authorization&.dig('status')
        }.compact
      end

      def payment_status(paypal_order)
        first_payment(paypal_order)&.dig('status') || paypal_order['status']
      end

      def first_payment(paypal_order)
        captures(paypal_order).first || authorizations(paypal_order).first
      end

      # Only the payable ones are canceled; a failed session's order can no
      # longer be completed by anyone.
      def replace_open_sessions(order)
        sessions = order.payment_sessions.where(payment_method: self)
        if sessions.exists?(status: 'completed')
          raise Spree::Core::GatewayError, I18n.t('spree.paypal_checkout.payment_session_errors.payment_in_progress')
        end

        sessions.active.order(:id).each do |payment_session|
          cancel_payment_session(payment_session: payment_session)
        end
      rescue Spree::Core::GatewayError
        raise
      rescue StandardError => e
        raise unless retryable_error?(e)

        # Checkout speaks GatewayError. The unused-session job does not: it
        # retries these, and has to see them unwrapped.
        raise Spree::Core::GatewayError, e.message
      end

      def retryable_error?(error)
        error.is_a?(PaypalServerSdk::ErrorException) ? retryable_paypal_error?(error) : error.is_a?(Faraday::Error) || error.is_a?(CoreLibrary::AuthValidationException)
      end

      def retryable_paypal_error?(error)
        error.response_code.in?(RETRYABLE_STATUS_CODES) || error.response_code.to_i >= 500
      end

      def client_external_data(external_data)
        external_data.to_h.stringify_keys.except(*OWNED_EXTERNAL_DATA_KEYS)
      end
    end
  end
end
