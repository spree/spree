require 'test_helper'

class RemoteSageTest < Test::Unit::TestCase

  def setup
    @gateway = SageGateway.new(fixtures(:sage))
    
    @amount = 100
    
    @visa        = credit_card("4111111111111111")
    @check       = check
    
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
  
  def test_successful_check_purchase
    assert response = @gateway.purchase(@amount, @check, @options)
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
  
  def test_authorization_and_capture
    assert auth = @gateway.authorize(@amount, @visa, @options)
    assert_success auth
    
    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
  end
  
  def test_visa_authorization_and_void
    assert auth = @gateway.authorize(@amount, @visa, @options)
    assert_success auth
    
    assert void = @gateway.void(auth.authorization)
    assert_success void
  end
  
  def test_check_purchase_and_void
    assert purchase = @gateway.purchase(@amount, @check, @options)
    assert_success purchase
    
    assert void = @gateway.void(purchase.authorization)
    assert_success void
  end

  def test_visa_credit
    assert response = @gateway.credit(@amount, @visa, @options)
    assert_success response
    assert response.test?
  end
  
  def test_check_credit
    assert response = @gateway.credit(@amount, @check, @options)
    assert_success response
    assert response.test?
  end
  
  def test_invalid_login
    gateway = SageGateway.new(
                :login => '',
                :password => ''
              )
    assert response = gateway.purchase(@amount, @visa, @options)
    assert_failure response
    assert_equal 'SECURITY VIOLATION', response.message
  end
end
