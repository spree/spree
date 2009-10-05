require 'test_helper'

class SecurePayTechTest < Test::Unit::TestCase
  def setup
    @gateway = SecurePayTechGateway.new(
                 :login => 'x',
                 :password => 'y'
               )

    @amount = 100
    @credit_card = credit_card('4987654321098769')
    @options = {
      :billing_address => address
    }
  end
  
  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
  
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response
    assert response.test?
    assert_equal '4--120119220646821', response.authorization
  end
  
  def test_unsuccessful_purchase
    @gateway.expects(:ssl_post).returns(unsuccessful_purchase_response)
  
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_failure response
    assert response.test?
  end
 
  private
  def successful_purchase_response
    "1,4--120119220646821,000000014511,23284,014511,20080125\r\n"
  end
  
  def unsuccessful_purchase_response
    "4,4--120119180936527,000000014510,23283,014510,20080125\r\n"
  end
end
