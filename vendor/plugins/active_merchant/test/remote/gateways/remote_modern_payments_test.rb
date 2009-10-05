require 'test_helper'

class RemoteModernPaymentTest < Test::Unit::TestCase
  

  def setup
    @gateway = ModernPaymentsGateway.new(fixtures(:modern_payments))
    
    @amount = 100
    @credit_card = credit_card('4111111111111111')
    @declined_card = credit_card('4000000000000000')
    
    @options = { 
      :order_id => '1',
      :billing_address => address,
      :description => 'Store Purchase'
    }
  end
  
  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_match /RESPONSECODE=A/, response.params["auth_string"]
    assert_equal ModernPaymentsCimGateway::SUCCESS_MESSAGE, response.message
  end

  def test_unsuccessful_purchase
    assert response = @gateway.purchase(@amount, @declined_card, @options)
    assert_success response
    assert_match /RESPONSECODE=D/, response.params["auth_string"]
    assert_equal ModernPaymentsCimGateway::SUCCESS_MESSAGE, response.message
  end

  def test_invalid_login
    gateway = ModernPaymentsGateway.new(
                :login => '',
                :password => ''
              )
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal ModernPaymentsCimGateway::ERROR_MESSAGE, response.message
  end
end
