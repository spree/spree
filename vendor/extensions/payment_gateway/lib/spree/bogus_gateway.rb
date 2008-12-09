# Specify this gateway in environment.rb and use the following credit card numbers for testing purposes
#
# VISA: 4111111111111111
# MC:   5500000000000004
# AMEX: 340000000000009
# DISC: 6011000000000004
# 
# NOTE: Based on ActiveMerchant's Bogus Gateway with some added improvements
module Spree #:nodoc:
  class BogusGateway
    TEST_VISA = "4111111111111111" 
    TEST_MC = "5500000000000004"
    TEST_AMEX = "340000000000009"  
    TEST_DISC = "6011000000000004"
    
    VALID_CCS = ["1", TEST_VISA, TEST_MC, TEST_AMEX, TEST_DISC]
    
    def initialize(options = {})

    end
    
    def authorize(money, creditcard, options = {})      
      if VALID_CCS.include? creditcard.number 
        ActiveMerchant::Billing::Response.new(true, "Bogus Gateway: Forced success", {}, :test => true, :authorization => '12345')
      else
        ActiveMerchant::Billing::Response.new(false, "Bogus Gateway: Forced failure", {:message => 'Bogus Gateway: Forced failure'}, :test => true)
      end      
    end

    def purchase(money, creditcard, options = {})
      if VALID_CCS.include? creditcard.number 
        ActiveMerchant::Billing::Response.new(true, "Bogus Gateway: Forced success", {}, :test => true, :authorization => '12345')
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
    
    # Always in test mode
    def test?
      true
    end
    
  end
end
