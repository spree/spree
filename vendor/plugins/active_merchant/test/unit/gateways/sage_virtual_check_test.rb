require 'test_helper'

class SageVirtualCheckTest < Test::Unit::TestCase
  def setup
    @gateway = SageVirtualCheckGateway.new(
                 :login => 'login',
                 :password => 'password'
               )

    @check = check

    @options = { 
      :order_id => generate_unique_id,
      :billing_address => address,
      :shipping_address => address,
      :email => 'longbob@example.com',
      :drivers_license_state => 'CA',
      :drivers_license_number => '12345689',
      :date_of_birth => Date.new(1978, 8, 11),
      :ssn => '078051120'
    }
  end
  
  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    
    assert response = @gateway.purchase(@amount, @check, @options)
    assert_instance_of Response, response
    assert_success response
    
    assert_equal "ACCEPTED", response.message
    assert_equal "C5O8NUdNt0;virtual_check", response.authorization
                                         
    assert_equal "A",                    response.params["success"]
    assert_equal "",                     response.params["code"]
    assert_equal "ACCEPTED",             response.params["message"]
    assert_equal "00",                   response.params["risk"]
    assert_equal "C5O8NUdNt0",           response.params["reference"]
    assert_equal "89be635e663b05eca587", response.params["order_number"]
    assert_equal  "0",                   response.params["authentication_indicator"]
    assert_equal  "NONE",                response.params["authentication_disclosure"]
  end
  
  def test_declined_purchase
    @gateway.expects(:ssl_post).returns(declined_purchase_response)
    
    assert response = @gateway.purchase(@amount, @check, @options)
    assert_failure response
    assert response.test?
    assert_equal "INVALID C_RTE", response.message
    assert_equal "C5O8NR6Nr0;virtual_check", response.authorization

    assert_equal "X",                    response.params["success"]
    assert_equal "900016",               response.params["code"]
    assert_equal "INVALID C_RTE",        response.params["message"]
    assert_equal "00",                   response.params["risk"]
    assert_equal "C5O8NR6Nr0",           response.params["reference"]
    assert_equal "d98cf50f7a2430fe04ad", response.params["order_number"]
    assert_equal  "0",                    response.params["authentication_indicator"]
    assert_equal  nil,                    response.params["authentication_disclosure"]
  end
  
  private
  def successful_purchase_response
    "\002A      ACCEPTED                        00C5O8NUdNt0\03489be635e663b05eca587\0340\034NONE\034\003"
  end
  
  def declined_purchase_response
    "\002X900016INVALID C_RTE                   00C5O8NR6Nr0\034d98cf50f7a2430fe04ad\0340\034\034\003"
  end
end
