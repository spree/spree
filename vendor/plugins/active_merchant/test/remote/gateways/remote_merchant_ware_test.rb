require 'test_helper'

class RemoteMerchantWareTest < Test::Unit::TestCase
  def setup
    @gateway = MerchantWareGateway.new(fixtures(:merchant_ware))
    
    @amount = rand(100) + 100
    
    @credit_card = credit_card('5105105105105100')
    
    @options = { 
      :order_id => generate_unique_id,
      :billing_address => address
    }
  end
  
  def test_successful_authorization
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'APPROVED', response.message
  end
  
  def test_unsuccessful_authorization
    @credit_card.number = "1234567890123"
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
  end
  
  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'APPROVED', response.message
  end
  
  def test_unsuccessful_purchase
    @credit_card.number = "1234567890123"
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
  end
    
  def test_authorize_and_capture
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert auth.authorization
    assert capture = @gateway.capture(@amount, auth.authorization, @options)
    assert_success capture
  end
  
  def test_authorize_and_credit
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert auth.authorization
    
    assert credit = @gateway.credit(@amount, @credit_card, @options)
    assert_success credit
    assert_not_nil credit.authorization
  end
  
  def test_purchase_and_credit
    assert purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase
    assert purchase.authorization
    
    assert credit = @gateway.credit(@amount, @credit_card, @options)
    assert_success credit
    assert_not_nil credit.authorization
  end
  
  def test_purchase_and_reference_credit
    assert auth = @gateway.purchase(@amount, @credit_card, @options)
    assert_success auth
    assert auth.authorization
    
    assert credit = @gateway.credit(@amount, auth.authorization, @options)
    assert_success credit
    assert_not_nil credit.authorization
  end
  
  def test_purchase_and_void
    assert purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase
  
    assert void = @gateway.void(purchase.authorization)
    assert_success void
  end

  # seems as though only purchases can be voided
  def test_authorization_and_failed_void
    assert authorization = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorization
  
    assert void = @gateway.void(authorization.authorization)
    assert_failure void
  end
  
  def test_failed_capture
    assert response = @gateway.capture(@amount, '', @options)
    assert_failure response
    assert_equal 'Server was unable to process request. ---> strReferenceCode should be at least 1 to at most 100 characters in size. Parameter name: strReferenceCode', response.message
  end

  def test_invalid_login
    gateway = MerchantWareGateway.new(
                :login => '',
                :password => '',
                :name => ''
              )
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Server was unable to process request. ---> Invalid Credentials.', response.message
  end
end
