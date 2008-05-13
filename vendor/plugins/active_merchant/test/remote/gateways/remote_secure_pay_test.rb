require File.dirname(__FILE__) + '/../../test_helper'

class RemoteSecurePayTest < Test::Unit::TestCase  
  
  def setup
    @gateway = SecurePayGateway.new(fixtures(:secure_pay))

    @credit_card = credit_card('4111111111111111',
      :month => '7',
      :year  => '2007'
    )
    
    @options = { :order_id => generate_unique_id,
      :description => 'Store purchase',
      :billing_address => address
    }
    
    @amount = 100
  end
  
  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert response.success?
    assert response.test?
    assert_equal 'This transaction has been approved', response.message
    assert response.authorization
  end
end
