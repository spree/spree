require File.dirname(__FILE__) + '/../../test_helper'

class RemoteTransFirstTest < Test::Unit::TestCase

  def setup
    @gateway = TransFirstGateway.new(fixtures(:trans_first))

    @credit_card = credit_card('4111111111111111')
    @amount = 100
    @options = { 
      :order_id => generate_unique_id,
      :invoice => 'ActiveMerchant Sale',
      :billing_address => address
    }
  end
  
  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'test transaction', response.message
    assert response.test?
    assert_success response
    assert !response.authorization.blank?
  end

  def test_invalid_login
    gateway = TransFirstGateway.new(
      :login => '',
      :password => ''
    )
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'invalid account', response.message
    assert_failure response
  end
end
