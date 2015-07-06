module Spree
  class Gateway::Bogus < Gateway
    TEST_VISA = ['4111111111111111','4012888888881881','4222222222222']
    TEST_MC   = ['5500000000000004','5555555555554444','5105105105105100']
    TEST_AMEX = ['378282246310005','371449635398431','378734493671000','340000000000009']
    TEST_DISC = ['6011000000000004','6011111111111117','6011000990139424']

    VALID_CCS = ['1', TEST_VISA, TEST_MC, TEST_AMEX, TEST_DISC].flatten

    attr_accessor :test

    def provider_class
      self.class
    end

    def preferences
      {}
    end

    def create_profile(payment)
      return if payment.source.has_payment_profile?
      # simulate the storage of credit card profile using remote service
      if success = VALID_CCS.include?(payment.source.number)
        payment.source.update_attributes(:gateway_customer_profile_id => generate_profile_id(success))
      end
    end

    def authorize(money, credit_card, options = {})
      profile_id = credit_card.gateway_customer_profile_id
      if VALID_CCS.include? credit_card.number or (profile_id and profile_id.starts_with? 'BGS-')
        ActiveMerchant::Billing::Response.new(true, 'Bogus Gateway: Forced success', {}, :test => true, :authorization => '12345', :avs_result => { :code => 'D' })
      else
        ActiveMerchant::Billing::Response.new(false, 'Bogus Gateway: Forced failure', { :message => 'Bogus Gateway: Forced failure' }, :test => true)
      end
    end

    def purchase(money, credit_card, options = {})
      profile_id = credit_card.gateway_customer_profile_id
      if VALID_CCS.include? credit_card.number  or (profile_id and profile_id.starts_with? 'BGS-')
        ActiveMerchant::Billing::Response.new(true, 'Bogus Gateway: Forced success', {}, :test => true, :authorization => '12345', :avs_result => { :code => 'M' })
      else
        ActiveMerchant::Billing::Response.new(false, 'Bogus Gateway: Forced failure', :message => 'Bogus Gateway: Forced failure', :test => true)
      end
    end

    def credit(money, credit_card, response_code, options = {})
      ActiveMerchant::Billing::Response.new(true, 'Bogus Gateway: Forced success', {}, :test => true, :authorization => '12345')
    end

    def capture(money, authorization, gateway_options)
      if authorization == '12345'
        ActiveMerchant::Billing::Response.new(true, 'Bogus Gateway: Forced success', {}, :test => true)
      else
        ActiveMerchant::Billing::Response.new(false, 'Bogus Gateway: Forced failure', :error => 'Bogus Gateway: Forced failure', :test => true)
      end

    end

    def void(response_code, credit_card, options = {})
      ActiveMerchant::Billing::Response.new(true, 'Bogus Gateway: Forced success', {}, :test => true, :authorization => '12345')
    end

    def cancel(_response_code)
      ActiveMerchant::Billing::Response.new(true, 'Bogus Gateway: Forced success', {}, test: true, authorization: '12345')
    end

    def test?
      # Test mode is not really relevant with bogus gateway (no such thing as live server)
      true
    end

    def payment_profiles_supported?
      true
    end

    def actions
      %w(capture void credit)
    end

    private
      def generate_profile_id(success)
        record = true
        prefix = success ? 'BGS' : 'FAIL'
        while record
          random = "#{prefix}-#{Array.new(6){rand(6)}.join}"
          record = CreditCard.where(:gateway_customer_profile_id => random).first
        end
        random
      end
  end
end
