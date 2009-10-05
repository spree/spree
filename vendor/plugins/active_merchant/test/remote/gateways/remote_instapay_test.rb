require 'test_helper'

class RemoteInstapayTest < Test::Unit::TestCase
  
  def setup
    @gateway = InstapayGateway.new(fixtures(:instapay))

    @amount = 100
    @credit_card = credit_card('5454545454545454')
    @declined_card = credit_card('4000300011112220')

    @options = {
      :order_id => generate_unique_id,
      :billing_address => address,
      :shipping_address => address,
      :description => 'Store Purchase'
    }
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal InstapayGateway::SUCCESS_MESSAGE, response.message
  end

  def test_failed_purchase
    assert response = @gateway.purchase(@amount,  @declined_card, @options)
    assert_failure response
  end

  def test_succesful_authorization
    assert response = @gateway.authorize(@amount,  @credit_card, @options)
    assert_success response
    assert_equal InstapayGateway::SUCCESS_MESSAGE, response.message
  end

  def test_failed_authorization
    assert response = @gateway.authorize(@amount,  @declined_card, @options)
    assert_failure response
  end
  
  def test_authorization_and_capture
    assert authorization = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorization
  
    assert capture = @gateway.capture(@amount, authorization.authorization)
    assert_success capture
    assert_equal InstapayGateway::SUCCESS_MESSAGE, capture.message
  end
  
  def test_invalid_login
    gateway = InstapayGateway.new(
      :login => 'X',
      :password => 'Y'
    )
    
    assert response = gateway.purchase(@amount, @credit_card)
    assert_failure response
    assert_equal "Invalid merchant", response.message
  end
end
