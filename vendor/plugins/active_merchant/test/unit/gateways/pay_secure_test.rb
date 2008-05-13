require File.dirname(__FILE__) + '/../../test_helper'

class PaySecureTest < Test::Unit::TestCase
  
  def setup
    @gateway = PaySecureGateway.new(
                 :login => 'login',
                 :password => 'password'
               )

    @credit_card = credit_card
    @options = { 
      :order_id => '1000',
      :billing_address => address,
      :description => 'Test purchase'
    }
    @amount = 100
  end
  
  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response
    assert_equal '2778;SimProxy 54041670', response.authorization
    assert response.test?
  end
  
  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failure_response)
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_equal "Field value '8f796cb29a1be32af5ce12d4ca7425c2' does not match required format.", response.message
    assert_failure response
  end
  
  def test_avs_result_not_supported
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    
    response = @gateway.purchase(@amount, @credit_card, @options)    
    assert_nil response.avs_result['code']
  end
  
  def test_cvv_result_not_supported
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_nil response.cvv_result['code']
  end
  
  private
  def successful_purchase_response
    <<-RESPONSE
Status: Accepted
SettlementDate: 2007-10-09
AUTHNUM: 2778
ErrorString: No Error
CardBin: 1
ERROR: 0
TransID: SimProxy 54041670
    RESPONSE
  end
  
  def failure_response
    <<-RESPONSE
Status: Declined
ErrorString: Field value '8f796cb29a1be32af5ce12d4ca7425c2' does not match required format.
ERROR: 1
    RESPONSE
  end
end
