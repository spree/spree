require 'test_helper'

class ViaklixTest < Test::Unit::TestCase

  def setup
    @gateway = ViaklixGateway.new(
      :login => 'LOGIN',
      :password => 'PIN'
    )
    
    @credit_card = credit_card    
    @options = {
      :order_id => '37',
      :email => "paul@domain.com",
      :description => 'Test Transaction',
      :billing_address => address
    }
    @amount = 100
  end
  
  def test_purchase_success    
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response
    assert_equal '7E2419F7-2354-4766-BF5C-19C75A1F379A', response.authorization
  end

  def test_purchase_error
    @gateway.expects(:ssl_post).returns(unsuccessful_purchase_response)
    
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_failure response
  end
  
  def test_invalid_login
    @gateway.expects(:ssl_post).returns(invalid_login_response)
    
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    
    assert_equal '7000', response.params['result']
    assert_equal 'The viaKLIX ID and/or User ID supplied in the authorization request is invalid.', response.params['result_message']
    assert_failure response
  end
  
  def test_avs_result
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    
    response = @gateway.purchase(@amount, @credit_card)
    assert_equal 'Y', response.avs_result['code']
  end
  
  def test_cvv_result
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    
    response = @gateway.purchase(@amount, @credit_card)
    assert_equal 'M', response.cvv_result['code']
  end
  
  private
  
  def successful_purchase_response
    "ssl_result=0\r\nssl_company=;\r\nssl_city=Herndon\r\nssl_avs_zip=90201\r\nssl_address2=\r\nssl_ship_to_last_name=Jacobs\r\nssl_ship_to_city=Herndon\r\nssl_approval_code=05737D\r\nssl_avs_response=Y\r\nssl_salestax=\r\nssl_ship_to_phone=\r\ncustomer_code=jacobsr1@cox.net\r\nship_to_country=US\r\ncountry=US\r\nssl_txn_id=7E2419F7-2354-4766-BF5C-19C75A1F379A\r\nssl_transaction_type=SALE\r\nssl_invoice_number=#1158.1\r\nssl_amount=243.95\r\nssl_card_number=43*******6820\r\nssl_description=\r\nssl_phone=703-404-9270\r\nssl_ship_to_avs_address=\r\nssl_first_name=Cody\r\nssl_avs_address=12213 Jonathons Glen Way\r\nssl_result_message=APPROVED\r\nssl_exp_date=1109\r\nssl_last_name=Fauser\r\nssl_ship_to_first_name=Robert\r\nssl_ship_to_address2=\r\nssl_ship_to_state=VA\r\nssl_ship_to_avs_zip=\r\nssl_cvv2_response=M\r\nssl_state=VA\r\nssl_email=cody@example.com\r\nssl_ship_to_company=\r\n"
  end
  
  def unsuccessful_purchase_response
    "ssl_result=1\r\nssl_result_message=This transaction request has not been approved. You may elect to use another form of payment to complete this transaction or contact customer service for additional options."
  end
  
  def invalid_login_response
    <<-RESPONSE
ssl_result=7000\r
ssl_result_message=The viaKLIX ID and/or User ID supplied in the authorization request is invalid.\r
    RESPONSE
  end
end