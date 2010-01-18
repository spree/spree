class Gateway::Bogus < Gateway
  TEST_VISA = "4111111111111111"
  TEST_MC = "5500000000000004"
  TEST_AMEX = "340000000000009"
  TEST_DISC = "6011000000000004"

  VALID_CCS = ["1", TEST_VISA, TEST_MC, TEST_AMEX, TEST_DISC]

  attr_accessor :test

  def provider_class
    self.class
  end

  def preferences
    {}
  end

  def authorize(money, creditcard, options = {})
    if VALID_CCS.include? creditcard.number
      ActiveMerchant::Billing::Response.new(true, "Bogus Gateway: Forced success", {}, :test => true, :authorization => '12345', :avs_result => {:code => 'A'})
    else
      ActiveMerchant::Billing::Response.new(false, "Bogus Gateway: Forced failure", {:message => 'Bogus Gateway: Forced failure'}, :test => true)
    end
  end

  def purchase(money, creditcard, options = {})
    if VALID_CCS.include? creditcard.number
      ActiveMerchant::Billing::Response.new(true, "Bogus Gateway: Forced success", {}, :test => true, :authorization => '12345', :avs_result => {:code => 'A'})
    else
      ActiveMerchant::Billing::Response.new(false, "Bogus Gateway: Forced failure", :message => 'Bogus Gateway: Forced failure', :test => true)
    end
  end

  def credit(money, ident, options = {})
    if ident == "12345"
      ActiveMerchant::Billing::Response.new(true, "Bogus Gateway: Forced success", {}, :test => true, :authorization => '12345')
    else
      ActiveMerchant::Billing::Response.new(false, "Bogus Gateway: Forced failure", :error => 'Bogus Gateway: Forced failure', :test => true)
    end
  end

  def capture(money, ident, options = {})
    if ident == "12345"
      ActiveMerchant::Billing::Response.new(true, "Bogus Gateway: Forced success", {}, :test => true, :authorization => '12345')
    else
      ActiveMerchant::Billing::Response.new(false, "Bogus Gateway: Forced failure", :error => 'Bogus Gateway: Forced failure', :test => true)
    end
  end

  def void(ident, options = {})
    if ident == "12345"
      ActiveMerchant::Billing::Response.new(true, "Bogus Gateway: Forced success", {}, :test => true, :authorization => '12345')
    else
      ActiveMerchant::Billing::Response.new(false, "Bogus Gateway: Forced failure", :error => 'Bogus Gateway: Forced failure', :test => true)
    end
  end

  def test?
    # Test mode is not really relevant with bogus gateway (no such thing as live server)
    true
  end

end