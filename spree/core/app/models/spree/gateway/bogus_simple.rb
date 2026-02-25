# Bogus Gateway that doesn't support payment profiles
module Spree
  class Gateway::BogusSimple < Gateway::Bogus
    def payment_profiles_supported?
      false
    end

    def authorize(_money, credit_card, _options = {})
      if VALID_CCS.include? credit_card.number
        Spree::PaymentResponse.new(true, 'Bogus Gateway: Forced success', {}, test: true, authorization: '12345', avs_result: { code: 'A' })
      else
        Spree::PaymentResponse.new(false, 'Bogus Gateway: Forced failure', { message: 'Bogus Gateway: Forced failure' }, test: true)
      end
    end

    def purchase(_money, credit_card, _options = {})
      if VALID_CCS.include? credit_card.number
        Spree::PaymentResponse.new(true, 'Bogus Gateway: Forced success', {}, test: true, authorization: '12345', avs_result: { code: 'A' })
      else
        Spree::PaymentResponse.new(false, 'Bogus Gateway: Forced failure', message: 'Bogus Gateway: Forced failure', test: true)
      end
    end
  end
end
