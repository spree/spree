require 'test_helper'

class VerifiTest < Test::Unit::TestCase
  include ActiveMerchant::Billing

  def setup
    @gateway = VerifiGateway.new(fixtures(:verify))
    
    @credit_card = credit_card('4111111111111111')
    
    #  Replace with your login and password for the Verifi test environment
    @options = {
      :order_id => '37',
      :email => "test@example.com",   
      :billing_address => address
    }
    
    @amount = 100
  end
  
  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Transaction was Approved', response.message
    assert !response.authorization.blank?
  end
  
  def test_unsuccessful_purchase
    @credit_card.number = 'invalid'
    
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Transaction was Rejected by Gateway', response.message
  end
  
  # FOR SOME REASON Verify DOESN'T MIND EXPIRED CARDS
  # I talked to support and they said that they are loose on expiration dates being expired.
  def test_expired_credit_card
    @credit_card.year = (Time.now.year - 3) 
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Transaction was Approved', response.message   
  end
    
  def test_successful_authorization
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Transaction was Approved', response.message
    assert response.authorization
  end
  
  def test_authorization_and_capture
    assert authorization = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorization
    assert authorization
    assert capture = @gateway.capture(@amount, authorization.authorization, @options)  
    assert_success capture
    assert_equal 'Transaction was Approved', capture.message
  end
  
  def test_authorization_and_void
    assert authorization = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorization
    assert authorization
    assert void = @gateway.void(authorization.authorization, @options)
    assert_success void
    assert_equal 'Transaction was Approved', void.message
  end
  
  # Credits are not enabled on test accounts, so this should always fail  
  def test_credit
    assert response = @gateway.credit(@amount, @credit_card, @options)
    assert_match /Credits are not enabled/, response.params['responsetext']
    assert_failure response  
  end
  
  def test_authorization_and_void
    assert authorization = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorization
    assert void = @gateway.void(authorization.authorization, @options)
    assert_success void
    assert_equal 'Transaction was Approved', void.message
    assert_match /Transaction Void Successful/, void.params['responsetext']
  end
  
  def test_purchase_and_credit
    assert purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase
    
    assert credit = @gateway.credit(@amount, purchase.authorization, @options)
    assert_success credit
    assert_equal 'Transaction was Approved', credit.message
  end
  
  def test_bad_login
    gateway = VerifiGateway.new(
      :login => 'X',
      :password => 'Y'
    )
    
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'Transaction was Rejected by Gateway', response.message
    assert_equal 'Authentication Failed', response.params['responsetext']
    
    assert_failure response
  end
end
