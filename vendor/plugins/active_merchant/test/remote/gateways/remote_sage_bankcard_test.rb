require 'test_helper'

class RemoteSageBankcardTest < Test::Unit::TestCase

  def setup
    @gateway = SageBankcardGateway.new(fixtures(:sage))
    
    @amount = 100
    
    @visa        = credit_card("4111111111111111")
    @mastercard  = credit_card("5499740000000057")
    @discover    = credit_card("6011000993026909")
    @amex        = credit_card("371449635392376")
    
    @options = { 
      :order_id => generate_unique_id,
      :billing_address => address,
      :shipping_address => address,
      :email => 'longbob@example.com'
    }
  end
    
  def test_successful_visa_purchase
    assert response = @gateway.purchase(@amount, @visa, @options)
    assert_success response
    assert response.test?
    assert_false response.authorization.blank?
  end
  
  def test_successful_visa_authorization
    assert response = @gateway.authorize(@amount, @visa, @options)
    assert_success response
    assert response.test?
    assert_false response.authorization.blank?
  end
  
  def test_declined_visa_purchase
    @amount = 200
    
    assert response = @gateway.purchase(@amount, @visa, @options)
    assert_failure response
    assert response.test?
  end
  
  def test_successful_mastercard_purchase
    assert response = @gateway.purchase(@amount, @mastercard, @options)
    assert_success response
    assert response.test?
    assert_false response.authorization.blank?
  end
  
  def test_successful_discover_purchase
    assert response = @gateway.purchase(@amount, @discover, @options)
    assert_success response
    assert response.test?
    assert_false response.authorization.blank?
  end
  
  def test_successful_amex_purchase
    assert response = @gateway.purchase(@amount, @amex, @options)
    assert_success response
    assert response.test?
    assert_false response.authorization.blank?
  end
  
  def test_authorization_and_capture
    assert auth = @gateway.authorize(@amount, @visa, @options)
    assert_success auth
    
    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
  end
  
  def test_failed_capture
    assert response = @gateway.capture(@amount, '')
    assert_failure response
    assert_equal 'INVALID T_REFERENCE', response.message
  end
  
  def test_authorization_and_void
    assert auth = @gateway.authorize(@amount, @visa, @options)
    assert_success auth
    
    assert void = @gateway.void(auth.authorization)
    assert_success void
  end
  
  def test_failed_void
    assert response = @gateway.void('')
    assert_failure response
    assert_equal 'INVALID T_REFERENCE', response.message
  end
  
  def test_successful_credit
    assert response = @gateway.credit(@amount, @visa, @options)
    assert_success response
    assert response.test?
  end

  def test_invalid_login
    gateway = SageBankcardGateway.new(
                :login => '',
                :password => ''
              )
    assert response = gateway.purchase(@amount, @visa, @options)
    assert_failure response
    assert_equal 'SECURITY VIOLATION', response.message
  end
end
