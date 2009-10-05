require 'test_helper'

class InstapayTest < Test::Unit::TestCase
  def setup
    @gateway = InstapayGateway.new(:login => 'TEST0')
    @credit_card = credit_card
    @amount = 100
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card)
    assert_instance_of  Response, response
    assert_success response
    assert_equal "118583850", response.authorization
  end

  def test_unsuccessful_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card)
    assert_instance_of Response, response
    assert_failure response
    assert_nil response.authorization
  end

  def test_successful_auth
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    assert response = @gateway.authorize(@amount, @credit_card)
    assert_instance_of  Response, response
    assert_success response
    assert_equal "118583850", response.authorization
  end

  def test_unsuccessful_auth
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    assert response = @gateway.authorize(@amount, @credit_card)
    assert_instance_of Response, response
    assert_failure response
    assert_nil response.authorization
  end
  
  def test_avs_result
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    
    response = @gateway.purchase(@amount, @credit_card)
    assert_equal 'X', response.avs_result['code']
  end
  
  def test_cvv_result
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    
    response = @gateway.purchase(@amount, @credit_card)
    assert_equal 'M', response.cvv_result['code']
  end
  
  def test_successful_capture
    @gateway.expects(:ssl_post).returns(successful_capture_response)
    
    response = @gateway.capture(100, "123456")
    assert_equal InstapayGateway::SUCCESS_MESSAGE, response.message
  end
  
  def test_failed_capture
    @gateway.expects(:ssl_post).returns(failed_capture_response)
    
    response = @gateway.capture(100, "123456")
    assert_equal "Post amount exceeds Auth amount", response.message
  end

  private

  # Place raw successful response from gateway here
  def successful_purchase_response
    "<html><body><plaintext>\r\nAccepted=SALE:TEST:::118583850:X::M\r\nhistoryid=118583850\r\norderid=92886714\r\nAccepted=SALE:TEST:::118583850:::\r\nACCOUNTNUMBER=************5454\r\nauthcode=TEST\r\nAuthNo=SALE:TEST:::118583850:::\r\nhistoryid=118583850\r\norderid=92886714\r\nrecurid=0\r\nrefcode=118583850-TEST\r\nresult=1\r\nStatus=Accepted\r\ntransid=0\r\n"
  end

  # Place raw failed response from gateway here
  def failed_purchase_response
    "<html><body><plaintext>\r\nDeclined=DECLINED:0720930009:CVV2 MISMATCH:N7\r\nhistoryid=118583848\r\norderid=92886713\r\nACCOUNTNUMBER=************2220\r\nDeclined=DECLINED:0720930009:CVV2 MISMATCH:N7\r\nhistoryid=118583848\r\norderid=92886713\r\nrcode=0720930009\r\nReason=DECLINED:0720930009:CVV2 MISMATCH:N7\r\nrecurid=0\r\nresult=0\r\nStatus=Declined\r\ntransid=80410586\r\n"
  end
  
  def successful_auth_response
    "<html><body><plaintext>\r\nAccepted=AUTH:TEST:::118585994:::\r\nhistoryid=118585994\r\norderid=92888143\r\nAccepted=AUTH:TEST:::118585994:::\r\nACCOUNTNUMBER=************5454\r\nauthcode=TEST\r\nAuthNo=AUTH:TEST:::118585994:::\r\nhistoryid=118585994\r\norderid=92888143\r\nrecurid=0\r\nrefcode=118585994-TEST\r\nresult=1\r\nStatus=Accepted\r\ntransid=0\r\n"
  end

  def failed_auth_response
    "<html><body><plaintext>\r\nDeclined=DECLINED:0720930009:CVV2 MISMATCH:N7\r\nhistoryid=118585991\r\norderid=92888142\r\nACCOUNTNUMBER=************2220\r\nDeclined=DECLINED:0720930009:CVV2 MISMATCH:N7\r\nhistoryid=118585991\r\norderid=92888142\r\nrcode=0720930009\r\nReason=DECLINED:0720930009:CVV2 MISMATCH:N7\r\nrecurid=0\r\nresult=0\r\nStatus=Declined\r\ntransid=80412271\r\n"
  end
  
  def successful_capture_response
    "<html><body><plaintext>\r\nAccepted=AVSAUTH:TEST:::121609962::::DUPLICATE\r\nhistoryid=121609962\r\norderid=95009583\r\nAccepted=AVSAUTH:TEST:::121609962::::DUPLICATE\r\nACCOUNTNUMBER=************5454\r\nauthcode=TEST\r\nAuthNo=AVSAUTH:TEST:::121609962::::DUPLICATE\r\nDUPLICATE=1\r\nhistoryid=121609962\r\norderid=95009583\r\nrecurid=0\r\nrefcode=121609962-TEST\r\nresult=1\r\nStatus=Accepted\r\ntransid=0\r\n"
  end
  
  def failed_capture_response
    "<html><body><plaintext>\r\nDeclined=DECLINED:1101450002:Post amount exceeds Auth amount:\r\nhistoryid=\r\norderid=\r\nDeclined=DECLINED:1101450002:Post amount exceeds Auth amount:\r\nrcode=1101450002\r\nReason=DECLINED:1101450002:Post amount exceeds Auth amount:\r\nresult=0\r\nStatus=Declined\r\ntransid=0\r\n"
  end
end

