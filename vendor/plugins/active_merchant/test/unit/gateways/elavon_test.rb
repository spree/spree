require 'test_helper'

class ElavonTest < Test::Unit::TestCase
  def setup
    @gateway = ElavonGateway.new(
                 :login => 'login',
                 :user => 'user',
                 :password => 'password'
               )

    @credit_card = credit_card
    @amount = 100
    
    @options = { 
      :order_id => '1',
      :billing_address => address,
      :description => 'Store Purchase'
    }
  end
  
  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal '123456', response.authorization
    assert response.test?
  end
  
  def test_successful_authorization
    @gateway.expects(:ssl_post).returns(successful_authorization_response)
    
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response
    
    assert_equal '123456', response.authorization
    assert_equal "APPROVED", response.message
    assert response.test?
  end
  
  def test_failed_authorization
    @gateway.expects(:ssl_post).returns(failed_authorization_response)
  
    assert response = @gateway.authorize(@amount, @credit_card)
    assert_instance_of Response, response
    assert_failure response
  end

  def test_unsuccessful_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)
    
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end
  
  def test_invalid_login
    @gateway.expects(:ssl_post).returns(invalid_login_response)
    
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    
    assert_equal '7000', response.params['result']
    assert_equal 'The VirtualMerchant ID and/or User ID supplied in the authorization request is invalid.', response.message
    assert_failure response
  end

  def test_supported_countries
    assert_equal ['US', 'CA'], ElavonGateway.supported_countries
  end

  def test_supported_card_types
    assert_equal [:visa, :master, :american_express, :discover], ElavonGateway.supported_cardtypes
  end

  def test_avs_result
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    response = @gateway.purchase(@amount, @credit_card)
    assert_equal 'X', response.avs_result['code']
  end

  def test_cvv_result
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    response = @gateway.purchase(@amount, @credit_card)
    assert_equal 'P', response.cvv_result['code']
  end

  private
  def successful_purchase_response
    "ssl_card_number=42********4242
    ssl_exp_date=0910
    ssl_amount=1.00
    ssl_invoice_number=
    ssl_description=Test Transaction
    ssl_result=0
    ssl_result_message=APPROVED
    ssl_txn_id=00000000-0000-0000-0000-00000000000
    ssl_approval_code=123456
    ssl_cvv2_response=P
    ssl_avs_response=X
    ssl_account_balance=0.00
    ssl_txn_time=08/07/2009 09:54:18 PM"
  end
  
  def failed_purchase_response
    "errorCode=5000
    errorName=Credit Card Number Invalid
    errorMessage=The Credit Card Number supplied in the authorization request appears to be invalid."
  end
  
  def invalid_login_response
        <<-RESPONSE
    ssl_result=7000\r
    ssl_result_message=The VirtualMerchant ID and/or User ID supplied in the authorization request is invalid.\r
        RESPONSE
  end
  
  def successful_authorization_response
    "ssl_card_number=42********4242
    ssl_exp_date=0910
    ssl_amount=1.00
    ssl_invoice_number=
    ssl_description=Test Transaction
    ssl_result=0
    ssl_result_message=APPROVED
    ssl_txn_id=00000000-0000-0000-0000-00000000000
    ssl_approval_code=123456
    ssl_cvv2_response=P
    ssl_avs_response=X
    ssl_account_balance=0.00
    ssl_txn_time=08/07/2009 09:56:11 PM"
  end
  
  def failed_authorization_response
    "errorCode=5000
    errorName=Credit Card Number Invalid
    errorMessage=The Credit Card Number supplied in the authorization request appears to be invalid."
  end
end
