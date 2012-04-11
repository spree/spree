module Spree
  class Gateway::Bogus < Gateway
    TEST_VISA = '4111111111111111'
    TEST_MC   = '5500000000000004'
    TEST_AMEX = '340000000000009'
    TEST_DISC = '6011000000000004'

    VALID_CCS = ['1', TEST_VISA, TEST_MC, TEST_AMEX, TEST_DISC]

    attr_accessor :test

    def provider_class
      self.class
    end

    def preferences
      {}
    end

    def create_profile(payment)
      # simulate the storage of credit card profile using remote service
      success = VALID_CCS.include? payment.source.number
      payment.source.update_attributes(:gateway_customer_profile_id => generate_profile_id(success))
    end

    def authorize(money, creditcard, options = {})
      profile_id = creditcard.gateway_customer_profile_id
      if VALID_CCS.include? creditcard.number or (profile_id and profile_id.starts_with? 'BGS-')
        ActiveMerchant::Billing::Response.new(true, 'Bogus Gateway: Forced success', {}, :test => true, :authorization => '12345', :avs_result => { :code => 'A' })
      else
        ActiveMerchant::Billing::Response.new(false, 'Bogus Gateway: Forced failure', { :message => 'Bogus Gateway: Forced failure' }, :test => true)
      end
    end

    def purchase(money, creditcard, options = {})
      profile_id = creditcard.gateway_customer_profile_id
      if VALID_CCS.include? creditcard.number  or (profile_id and profile_id.starts_with? 'BGS-')
        ActiveMerchant::Billing::Response.new(true, 'Bogus Gateway: Forced success', {}, :test => true, :authorization => '12345', :avs_result => { :code => 'A' })
      else
        ActiveMerchant::Billing::Response.new(false, 'Bogus Gateway: Forced failure', :message => 'Bogus Gateway: Forced failure', :test => true)
      end
    end

    def credit(money, creditcard, response_code, options = {})
      ActiveMerchant::Billing::Response.new(true, 'Bogus Gateway: Forced success', {}, :test => true, :authorization => '12345')
    end

    def capture(authorization, creditcard, gateway_options)
      if authorization.response_code == '12345'
        ActiveMerchant::Billing::Response.new(true, 'Bogus Gateway: Forced success', {}, :test => true, :authorization => '67890')
      else
        ActiveMerchant::Billing::Response.new(false, 'Bogus Gateway: Forced failure', :error => 'Bogus Gateway: Forced failure', :test => true)
      end

    end

    def void(response_code, creditcard, options = {})
      ActiveMerchant::Billing::Response.new(true, 'Bogus Gateway: Forced success', {}, :test => true, :authorization => '12345')
    end

    def test?
      # Test mode is not really relevant with bogus gateway (no such thing as live server)
      true
    end

    def payment_profiles_supported?
      true
    end

    private
      def generate_profile_id(success)
        record = true
        prefix = success ? 'BGS' : 'FAIL'
        while record
          random = "#{prefix}-#{Array.new(6){rand(6)}.join}"
          record = Creditcard.where(:gateway_customer_profile_id => random).first
        end
        random
      end
  end
end
