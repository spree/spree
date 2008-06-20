require File.dirname(__FILE__) + '/../../test_helper'

class PsigateRemoteTest < Test::Unit::TestCase

  def setup
    Base.mode = :test
    @gateway = PsigateGateway.new(fixtures(:psigate))

    @amount = 2400
    @creditcard = credit_card('4242424242424242')
    @options = { 
      :order_id => generate_unique_id, 
      :billing_address => address,
      :email => 'jack@example.com' 
    }
  end
  
  def test_successful_authorization
    assert response = @gateway.authorize(@amount, @creditcard, @options)
    assert_success response
    assert_equal @options[:order_id], response.authorization
  end
  
  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @creditcard, @options)
    assert_success response
    assert_equal @options[:order_id], response.authorization
  end
  
  def test_successful_authorization_and_capture
    assert authorization = @gateway.authorize(@amount, @creditcard, @options)
    assert_success authorization
    
    assert capture = @gateway.capture(@amount, authorization.authorization)
    assert_success capture
  end
  
  def test_successful_purchase_and_credit
    assert purchase = @gateway.purchase(@amount, @creditcard, @options)
    assert_success purchase
    
    assert credit = @gateway.credit(@amount, purchase.authorization)
    assert_success credit
  end
  
  def test_failed_purchase
    assert response = @gateway.purchase(@amount, @creditcard, @options.update(:test_result => 'D'))
    assert_failure response
  end
end
