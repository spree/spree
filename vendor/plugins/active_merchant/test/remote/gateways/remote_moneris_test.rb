require 'test_helper'

class MonerisRemoteTest < Test::Unit::TestCase
  def setup
    Base.mode = :test

    @gateway = MonerisGateway.new(fixtures(:moneris))
    @amount = 100
    @credit_card = credit_card('4242424242424242')
    @options = { 
      :order_id => generate_unique_id,
      :billing_address => address,
      :description => 'Store Purchase'
    }
  end
  
  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Approved', response.message
    assert_false response.authorization.blank? 
  end
  
  def test_successful_authorization
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_false response.authorization.blank?
  end

  def test_failed_authorization
    response = @gateway.authorize(105, @credit_card, @options)
    assert_failure response
  end

  def test_successful_authorization_and_capture
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert response.authorization

    response = @gateway.capture(@amount, response.authorization)
    assert_success response
  end
  
  def test_successful_authorization_and_void
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert response.authorization
    
    void = @gateway.void(response.authorization)
    assert_success void
  end
  
  def test_successful_purchase_and_void
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase
    
    void = @gateway.void(purchase.authorization)
    assert_success void
  end
  
  def test_failed_purchase_and_void
    purchase = @gateway.purchase(101, @credit_card, @options)
    assert_failure purchase
    
    void = @gateway.void(purchase.authorization)
    assert_failure void
  end
  
  def test_successful_purchase_and_credit
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase
    
    credit = @gateway.credit(@amount, purchase.authorization)
    assert_success credit
  end

  def test_failed_purchase_from_error
    assert response = @gateway.purchase(150, @credit_card, @options)
    assert_failure response
    assert_equal 'Declined', response.message
  end
end
