require 'test_helper'

class RemoteModernPaymentsCimTest < Test::Unit::TestCase
  

  def setup
    @gateway = ModernPaymentsCimGateway.new(fixtures(:modern_payments))
    
    @amount = 100
    @credit_card = credit_card('4111111111111111')
    @declined_card = credit_card('4000000000000000')
    
    @options = { 
      :billing_address => address,
      :customer => 'JIMSMITH2000'
    }
  end
  
  def test_successful_create_customer
    response = @gateway.create_customer(@options)
    assert_success response
    assert !response.params["create_customer_result"].blank?
  end
  
  def test_successful_modify_customer_credit_card
    customer = @gateway.create_customer(@options)
    assert_success customer
    
    customer_id = customer.params["create_customer_result"]
    
    credit_card = @gateway.modify_customer_credit_card(customer_id, @credit_card)
    assert_success credit_card
    assert !credit_card.params["modify_customer_credit_card_result"].blank?
  end
  
  def test_succsessful_authorize_credit_card_payment
    customer = @gateway.create_customer(@options)
    assert_success customer
    
    customer_id = customer.params["create_customer_result"]
    
    credit_card = @gateway.modify_customer_credit_card(customer_id, @credit_card)
    assert_success credit_card
    
    payment = @gateway.authorize_credit_card_payment(customer_id, @amount)
    assert_success payment
  end

  def test_invalid_login
    gateway = ModernPaymentsCimGateway.new(
                :login => '',
                :password => ''
              )
    assert response = gateway.create_customer(@options)
    assert_failure response
    assert_equal ModernPaymentsCimGateway::ERROR_MESSAGE, response.message
  end
end
