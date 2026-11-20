module SpreeAdyen
  class Gateway < ::Spree::Gateway
    # Saving a card without a purchase: a zero-amount session in the store's
    # default currency, completed from the session result's stored payment
    # method id.
    module PaymentSetupSessions
      extend ActiveSupport::Concern

      def setup_session_supported?
        true
      end

      # @param customer [Spree::Customer]
      # @param external_data [Hash] `return_url` (required, on an allowed origin) and `channel`
      # @return [Spree::PaymentSetupSessions::Adyen]
      def create_payment_setup_session(customer:, external_data: {})
        data = external_data.to_h.stringify_keys
        return_url = allowed_return_url!(store, data['return_url'])
        presenter = SpreeAdyen::SessionPresenter.new(
          payment_method: self, customer: customer, return_url: return_url, channel: data['channel']
        )
        session = adyen_call(:create_setup_session) { |client| client.checkout.payments_api.sessions(presenter.to_h) }

        payment_setup_session_class.create!(
          customer: customer,
          payment_method: self,
          status: 'pending',
          external_id: session['id'],
          external_data: client_external_data(data).merge(session_external_data(session, presenter, return_url))
        )
      end

      # @param params [Hash] `session_result` from Drop-in
      def complete_payment_setup_session(setup_session:, params: {})
        session_result = completion_params(params)['session_result'].presence
        raise Spree::Core::GatewayError, I18n.t('spree.adyen.payment_session_errors.result_missing') if session_result.nil?

        result = SpreeAdyen::Result.from_session_result(
          adyen_call(:setup_session_result) do |client|
            client.checkout.payments_api.get_result_of_payment_session(setup_session.external_id, query_params: { sessionResult: session_result })
          end
        )

        case result.session_status
        when 'completed' then save_card(setup_session, result)
        when 'refused' then setup_session.fail
        when 'expired' then setup_session.expire
        else raise Spree::Core::GatewayError, refusal_message(result)
        end
        setup_session
      end

      private

      def save_card(setup_session, result)
        if result.stored_payment_method_id.blank?
          setup_session.fail
          setup_session.errors.add(:base, I18n.t('spree.adyen.payment_session_errors.token_missing'))
          return
        end

        credit_card = credit_card_from(result, customer: setup_session.customer)
        setup_session.update!(payment_source: credit_card)
        setup_session.complete
      end
    end
  end
end
