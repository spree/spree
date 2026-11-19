module SpreeAdyen
  class Gateway < ::Spree::Gateway
    # An Adyen checkout session, paid through Drop-in. It opens unpayable and
    # becomes payable only when the storefront submits it through Spree, at the
    # amount Spree holds, so canceling one Spree never made payable really
    # cancels it: Adyen refuses payment on it.
    module PaymentSessions
      extend ActiveSupport::Concern

      # Written by the gem; a client's values for them are ignored.
      OWNED_EXTERNAL_DATA_KEYS = %w[session_data client_key environment channel return_url reference manual_capture payable].freeze
      # Commands a client sends with an update or a completion, never stored.
      COMMAND_EXTERNAL_DATA_KEYS = %w[submit redirect_result].freeze

      # Opens a new session, canceling the cart's open Adyen sessions first.
      #
      # @param order [Spree::Cart, Spree::Order]
      # @param external_data [Hash] `return_url` (required, on an allowed origin) and `channel`
      # @return [Spree::PaymentSessions::Adyen]
      # @raise [Spree::Core::GatewayError] for a zero amount, a return URL outside
      #   the store's allowed origins, or a cart this method was already paid for
      def create_payment_session(order:, amount: nil, external_data: {})
        total = amount.present? ? BigDecimal(amount.to_s) : order.total_minus_store_credits
        raise Spree::Core::GatewayError, I18n.t('spree.adyen.payment_session_errors.zero_amount') unless total.positive?

        data = external_data.to_h.stringify_keys
        return_url = allowed_return_url!(order.store, data['return_url'])
        SpreeAdyen::Amounts.to_adyen(total, order.currency)
        replace_open_sessions(order)

        presenter = SpreeAdyen::SessionPresenter.new(
          payment_method: self, owner: order, amount: total, return_url: return_url, channel: data['channel']
        )
        body = presenter.to_h
        session = adyen_call(:create_session) do |client|
          client.checkout.payments_api.sessions(body, headers: { 'Idempotency-Key' => session_idempotency_key(presenter.reference, body) })
        end

        payment_session_class.create!(
          owner: order,
          payment_method: self,
          amount: total,
          currency: order.currency,
          status: 'pending',
          external_id: session['id'],
          customer: order.customer,
          expires_at: session['expiresAt'].presence && Time.zone.parse(session['expiresAt']),
          external_data: client_external_data(data).merge(
            session_external_data(session, presenter, return_url),
            'manual_capture' => presenter.manual_capture?,
            'payable' => false
          )
        )
      end

      # Before the session is payable a new amount changes Spree's figure only;
      # Drop-in shows it through its own update. An update carrying
      # `external_data.submit` makes the session payable.
      #
      # @raise [Spree::Core::GatewayError] for a new amount once the session is
      #   payable: the client opens a new session instead
      def update_payment_session(payment_session:, amount: nil, external_data: {})
        data = external_data.to_h.stringify_keys
        return submit_payment_session(payment_session) if ActiveModel::Type::Boolean.new.cast(data['submit'])

        attrs = {}
        new_amount = BigDecimal(amount.to_s) if amount.present?
        if new_amount && new_amount != payment_session.amount
          raise Spree::Core::GatewayError, I18n.t('spree.adyen.payment_session_errors.amount_locked') if payment_session.payable?

          SpreeAdyen::Amounts.to_adyen(new_amount, payment_session.currency)
          attrs[:amount] = new_amount
        end

        client_data = client_external_data(data)
        attrs[:external_data] = payment_session.external_data.merge(client_data) if client_data.any?
        payment_session.update!(attrs) if attrs.any?
        payment_session
      end

      # Reads what Adyen says about the session's payment and settles it, or
      # raises with Adyen's reason, leaving the session open for another try.
      # Does NOT complete the cart: the storefront's cart-complete call or the
      # webhook handler does that.
      #
      # @param params [Hash] `session_result` from Drop-in, or
      #   `external_data.redirect_result` from a buyer back from a redirect
      def complete_payment_session(payment_session:, params: {})
        params = completion_params(params)
        session_result = params['session_result'].presence
        redirect_result = params.dig('external_data', 'redirect_result').presence
        raise Spree::Core::GatewayError, I18n.t('spree.adyen.payment_session_errors.result_missing') if session_result.nil? && redirect_result.nil?

        result = if session_result
                   SpreeAdyen::Result.from_session_result(
                     adyen_call(:session_result) do |client|
                       client.checkout.payments_api.get_result_of_payment_session(
                         payment_session.external_id, query_params: { sessionResult: session_result }
                       )
                     end
                   )
                 else
                   SpreeAdyen::Result.from_payment_details(
                     adyen_call(:payment_details) do |client|
                       client.checkout.payments_api.payments_details({ details: { redirectResult: redirect_result } })
                     end
                   )
                 end

        apply_result(payment_session, result, redirect: redirect_result.present?)
      end

      # Local: Adyen has no call that cancels a session. For one never made
      # payable that is a real cancel.
      def cancel_payment_session(payment_session:)
        payment_session.cancel
      end

      # Whether Adyen took the money for this report: at once for some methods
      # whatever the session asked (Key Decision 10 of the design), never for
      # one it holds for a capture request, which CaptureHeldPaymentsSubscriber
      # sends once the order is placed.
      #
      # @param payment_session [Spree::PaymentSessions::Adyen]
      # @param result [SpreeAdyen::Result]
      def captured?(payment_session, result)
        return false unless result.authorised?

        return SpreeAdyen::Variants.captured_at_once?(result.variant) if payment_session.manual_capture?

        !SpreeAdyen::Variants.held_for_capture?(result.variant)
      end

      # The checks every report must pass before it settles anything: one
      # payment, for the session's amount and currency.
      #
      # @return [String, nil] what is wrong, or nil
      def settlement_problem(payment_session, result)
        if result.payments_count.to_i != 1
          I18n.t('spree.adyen.payment_session_errors.payments_count', count: result.payments_count.to_i)
        elsif result.amount != payment_session.amount || result.currency.to_s.upcase != payment_session.currency.to_s.upcase
          I18n.t('spree.adyen.payment_session_errors.amount_mismatch',
                 paid: "#{result.amount&.to_s('F')} #{result.currency}",
                 expected: "#{payment_session.amount.to_d.to_s('F')} #{payment_session.currency}")
        end
      end

      # A saved card, from a report that carries Adyen's stored payment method
      # id. Found among the customer's own cards only, so a token reported for
      # someone else never hands over their card's details.
      #
      # @return [Spree::CreditCard]
      def credit_card_from(result, customer:)
        Spree::CreditCard.find_or_create_by!(payment_method: self, customer: customer,
                                             gateway_payment_profile_id: result.stored_payment_method_id) do |card|
          card.gateway_customer_profile_id = "customer_#{customer.id}"
          card.cc_type = SpreeAdyen::Variants.card_brand(result.variant)
          card.last_digits = result.card_summary
          card.month = result.expiry_month
          card.year = result.expiry_year
          card.name = customer.full_name.presence || customer.email
          wallet = SpreeAdyen::Variants.wallet(result.variant)
          card.wallet = { 'type' => wallet } if wallet
        end
      end

      private

      def submit_payment_session(payment_session)
        raise Spree::Core::GatewayError, I18n.t('spree.adyen.payment_session_errors.not_open') unless payment_session.pending?
        return payment_session if payment_session.payable?

        body = {
          sessionData: payment_session.session_data,
          amount: SpreeAdyen::Amounts.to_adyen_amount(payment_session.amount, payment_session.currency),
          payable: true
        }
        session = adyen_call(:submit_session) do |client|
          client.checkout.payments_api.update_session(body, payment_session.external_id)
        end

        payment_session.update!(
          external_data: payment_session.external_data.merge('session_data' => session['sessionData'], 'payable' => true)
        )
        payment_session
      end

      def apply_result(payment_session, result, redirect:)
        case result.session_status
        when 'refused'
          payment_session.fail if payment_session.can_fail?
          return payment_session
        when 'expired'
          payment_session.expire if payment_session.can_expire?
          return payment_session
        end

        raise Spree::Core::GatewayError, refusal_message(result) unless result.settleable?

        settle(payment_session, result, redirect: redirect)
      end

      # A session Spree canceled after it was made payable still settles, and
      # stays canceled: a session completes only from pending or processing.
      def settle(payment_session, result, redirect:)
        problem = settlement_problem(payment_session, result)
        if problem.nil? && redirect && result.merchant_reference != payment_session.external_data['reference']
          problem = I18n.t('spree.adyen.payment_session_errors.reference_mismatch')
        end
        raise Spree::Core::GatewayError, problem if problem

        payment_session.process if payment_session.can_process?
        payment_session.settle_payment!(captured: captured?(payment_session, result), metadata: result.to_h)
        payment_session.complete
        payment_session
      end

      def refusal_message(result)
        reason = result.refusal_reason.presence || result.result_code.presence || result.session_status
        I18n.t('spree.adyen.payment_session_errors.refused', reason: reason)
      end

      # Only the payable ones are canceled; one already completed means this
      # cart has been paid through Adyen.
      def replace_open_sessions(order)
        sessions = order.payment_sessions.where(payment_method: self)
        raise Spree::Core::GatewayError, I18n.t('spree.adyen.payment_session_errors.already_paid') if sessions.exists?(status: 'completed')

        sessions.active.order(:id).each(&:cancel)
      end

      # The cart and its session count, plus a digest of the request: a retry
      # after a lost answer repeats it, while a request Adyen refused leaves no
      # session row, so a corrected one is told apart by what it asks for.
      def session_idempotency_key(reference, body)
        "spree-#{reference}-session-#{Digest::SHA256.hexdigest(body.except(:expiresAt).to_json).first(12)}"
      end

      def allowed_return_url!(store, return_url)
        return return_url if return_url.present? && store.allowed_origin?(return_url)

        raise Spree::Core::GatewayError, I18n.t('spree.adyen.payment_session_errors.return_url_not_allowed')
      end

      # @param data [Hash] the client's external data, string keys
      def client_external_data(data)
        data.except(*OWNED_EXTERNAL_DATA_KEYS, *COMMAND_EXTERNAL_DATA_KEYS)
      end

      # What the storefront and the gem need of any Adyen session.
      def session_external_data(session, presenter, return_url)
        {
          'session_data' => session['sessionData'],
          'client_key' => preferred_client_key,
          'environment' => environment,
          'channel' => presenter.channel,
          'return_url' => return_url,
          'reference' => presenter.reference
        }
      end

      def completion_params(params)
        hash = params.respond_to?(:to_unsafe_h) ? params.to_unsafe_h : params.to_h
        hash.deep_stringify_keys
      end
    end
  end
end
