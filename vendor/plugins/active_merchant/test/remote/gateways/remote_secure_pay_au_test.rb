require File.dirname(__FILE__) + '/../../test_helper'

class RemoteSecurePayAuTest < Test::Unit::TestCase
  
  def setup
    @gateway = SecurePayAuGateway.new(fixtures(:secure_pay_au))
    
    @amount = 100
    @credit_card = credit_card('4444333322221111')

    @options = { 
      :order_id => '1',
      :billing_address => address,
      :description => 'Store Purchase'
    }
  end
  
  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_unsuccessful_purchase
    @credit_card.year = '2005'
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'CARD EXPIRED', response.message
  end

  def test_invalid_login
    gateway = SecurePayAuGateway.new(
                :login => '',
                :password => ''
              )
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal "Invalid merchant ID", response.message
  end
end
