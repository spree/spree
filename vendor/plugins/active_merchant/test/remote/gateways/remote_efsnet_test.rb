require File.dirname(__FILE__) + '/../../test_helper'

class RemoteEfsnetTest < Test::Unit::TestCase
  
  def setup
    Base.gateway_mode = :test

    @gateway = EfsnetGateway.new(fixtures(:efsnet))
    
    @credit_card = credit_card('4000100011112224')
    
    @amount = 100
    @declined_amount = 156

    @options = { :order_id => generate_unique_id, 
                 :billing_address => address
               }
  end
  
  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Approved', response.message
    assert response.test?
  end

  def test_successful_force
    assert response = @gateway.force(@amount, '123456', @credit_card, @options)
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_successful_voice_authorize
    assert response = @gateway.voice_authorize(@amount, '123456', @credit_card, @options)
    assert_success response
    assert_equal 'Accepted', response.message
  end

  def test_unsuccessful_purchase
    assert response = @gateway.purchase(@declined_amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Declined', response.message
  end

  def test_authorize_and_capture
    amount = @amount
    assert auth = @gateway.authorize(amount, @credit_card, @options)
    assert_success auth    
    assert_equal 'Approved', auth.message
    assert auth.authorization
    
    assert capture = @gateway.capture(amount, auth.authorization, @options)
    assert_success capture
  end

  def test_purchase_and_void
    amount = @amount
    assert purchase = @gateway.purchase(amount, @credit_card, @options)
    assert_success purchase
    assert_equal 'Approved', purchase.message
    assert purchase.authorization
    assert void = @gateway.void(purchase.authorization, @options)
    assert_success void
  end

  def test_failed_capture
    assert response = @gateway.capture(@amount, '1;1', @options)
    assert_failure response
    assert_equal 'Bad original transaction', response.message
  end

  def test_invalid_login
    gateway = EfsnetGateway.new(
      :login => '',
      :password => ''
    )
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'Invalid credentials', response.message
    assert_failure response
  end
end
