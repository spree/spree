module Spree
  class Gateway::Bogus < Gateway
    TEST_VISA = ['4111111111111111', '4012888888881881', '4222222222222']
    TEST_MC   = ['5500000000000004', '5555555555554444', '5105105105105100', '2223000010309703']
    TEST_AMEX = ['378282246310005', '371449635398431', '378734493671000', '340000000000009']
    TEST_DISC = ['6011000000000004', '6011111111111117', '6011000990139424']

    VALID_CCS = ['1', TEST_VISA, TEST_MC, TEST_AMEX, TEST_DISC].flatten

    attr_accessor :test

    preference :dummy_key, :string, default: 'PUBLICKEY123'
    preference :dummy_secret_key, :password, default: 'SECRETKEY123'

    def provider_class
      self.class
    end

    def show_in_admin?
      false
    end

    def create_profile(payment)
      return if payment.source.has_payment_profile?

      # simulate the storage of credit card profile using remote service
      if success = VALID_CCS.include?(payment.source.number)
        payment.source.update(gateway_customer_profile_id: generate_profile_id(success))
      end
    end

    def authorize(_money, credit_card, _options = {})
      profile_id = credit_card.gateway_customer_profile_id
      if VALID_CCS.include?(credit_card.number) || (profile_id&.starts_with?('BGS-'))
        Spree::PaymentResponse.new(true, 'Bogus Gateway: Forced success', {}, test: true, authorization: '12345', avs_result: { code: 'D' })
      else
        Spree::PaymentResponse.new(false, 'Bogus Gateway: Forced failure', { message: 'Bogus Gateway: Forced failure' }, test: true)
      end
    end

    def purchase(_money, credit_card, _options = {})
      profile_id = credit_card.gateway_customer_profile_id
      if VALID_CCS.include?(credit_card.number) || (profile_id&.starts_with?('BGS-'))
        Spree::PaymentResponse.new(true, 'Bogus Gateway: Forced success', {}, test: true, authorization: '12345', avs_result: { code: 'M' })
      else
        Spree::PaymentResponse.new(false, 'Bogus Gateway: Forced failure', message: 'Bogus Gateway: Forced failure', test: true)
      end
    end

    def credit(_money, _credit_card, _response_code, _options = {})
      Spree::PaymentResponse.new(true, 'Bogus Gateway: Forced success', {}, test: true, authorization: '12345')
    end

    def capture(_money, authorization, _gateway_options)
      if authorization == '12345'
        Spree::PaymentResponse.new(true, 'Bogus Gateway: Forced success', {}, test: true)
      else
        Spree::PaymentResponse.new(false, 'Bogus Gateway: Forced failure', error: 'Bogus Gateway: Forced failure', test: true)
      end
    end

    def void(_response_code, _credit_card, _options = {})
      Spree::PaymentResponse.new(true, 'Bogus Gateway: Forced success', {}, test: true, authorization: 'void-12345')
    end

    def cancel(_response_code, _payment = nil)
      Spree::PaymentResponse.new(true, 'Bogus Gateway: Forced success', {}, test: true, authorization: '12345')
    end

    def test?
      # Test mode is not really relevant with bogus gateway (no such thing as live server)
      true
    end

    def confirmation_required?
      true
    end

    def payment_profiles_supported?
      true
    end

    def payment_source_class
      CreditCard
    end

    def session_required?
      true
    end

    def payment_session_class
      PaymentSessions::Bogus
    end

    def create_payment_session(order:, amount: nil, external_data: {})
      payment_session_class.create(
        order: order,
        payment_method: self,
        amount: amount.presence || order.total_minus_store_credits,
        currency: order.currency,
        status: 'pending',
        external_id: "bogus_#{SecureRandom.hex(12)}",
        external_data: external_data.merge('client_secret' => "bogus_secret_#{SecureRandom.hex(8)}"),
        customer: order.user
      )
    end

    def update_payment_session(payment_session:, amount: nil, external_data: {})
      attrs = {}
      attrs[:amount] = amount if amount.present?
      attrs[:external_data] = payment_session.external_data.merge(external_data) if external_data.present?
      payment_session.update(attrs)
    end

    def complete_payment_session(payment_session:, params: {})
      payment_session.complete
    end

    def setup_session_supported?
      true
    end

    def create_payment_setup_session(customer:, external_data: {})
      payment_setup_sessions.create(
        customer: customer,
        status: 'pending',
        external_id: "bogus_seti_#{SecureRandom.hex(12)}",
        external_client_secret: "bogus_seti_secret_#{SecureRandom.hex(8)}",
        external_data: external_data
      )
    end

    def complete_payment_setup_session(setup_session:, params: {})
      credit_card = CreditCard.create!(
        user: setup_session.customer,
        payment_method: self,
        name: 'Bogus Card',
        last_digits: '4242',
        month: '12',
        year: 1.year.from_now.year.to_s,
        gateway_customer_profile_id: "BGS-#{Array.new(6) { rand(6) }.join}"
      )
      setup_session.update!(payment_source: credit_card)
      setup_session.complete
    end

    def actions
      %w(capture void credit)
    end

    private

    def generate_profile_id(success)
      record = true
      prefix = success ? 'BGS' : 'FAIL'
      while record
        random = "#{prefix}-#{Array.new(6) { rand(6) }.join}"
        record = CreditCard.find_by(gateway_customer_profile_id: random)
      end
      random
    end

    def public_preference_keys
      [:dummy_key]
    end
  end
end
