require 'test_helper'

class MerchantWareTest < Test::Unit::TestCase
  def setup
    @gateway = MerchantWareGateway.new(
                 :login => 'login',
                 :password => 'password',
                 :name => 'name'
               )

    @credit_card = credit_card
    @amount = 100
    
    @options = { 
      :order_id => '1',
      :billing_address => address
    }
  end
  
  def test_successful_authorization
    @gateway.expects(:ssl_post).returns(successful_authorization_response)
    
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response
    
    assert_equal '4706382;1', response.authorization
    assert_equal "APPROVED", response.message
    assert response.test?
  end
  
  def test_soap_fault_during_authorization
    response_500 = stub(:code => "500", :message => "Internal Server Error", :body => fault_authorization_response)
    @gateway.expects(:ssl_post).raises(ActiveMerchant::ResponseError.new(response_500))
    
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_failure response
    assert response.test?
    
    assert_nil response.authorization
    assert_equal "Server was unable to process request. ---> strPAN should be at least 13 to at most 19 characters in size. Parameter name: strPAN", response.message
    assert_equal response_500.code, response.params["http_code"]
    assert_equal response_500.message, response.params["http_message"]
  end
    
  def test_failed_authorization
    @gateway.expects(:ssl_post).returns(failed_authorization_response)
    
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_failure response
    assert response.test?
    
    assert_nil response.authorization
    assert_equal "transaction type not supported by version", response.message
    assert_equal "FAILED", response.params["status"]
    assert_equal "1014", response.params["failure_code"]
  end
  
  def test_failed_void
    @gateway.expects(:ssl_post).returns(failed_void_response)
    
    assert response = @gateway.void("1")
    assert_instance_of Response, response
    assert_failure response
    assert response.test?
    
    assert_nil response.authorization
    assert_equal "decline", response.message
    assert_equal "DECLINED", response.params["status"]
    assert_equal "1012", response.params["failure_code"]
  end
  
  def test_avs_result
    @gateway.expects(:ssl_post).returns(successful_authorization_response)
    
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_equal 'N', response.avs_result['code']
  end
  
  def test_cvv_result
    @gateway.expects(:ssl_post).returns(successful_authorization_response)
    
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_equal 'M', response.cvv_result['code']
  end
  
  private
  
  def successful_authorization_response
    <<-XML
<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <soap:Body>
    <IssueKeyedPreAuthResponse xmlns="http://merchantwarehouse.com/MerchantWARE/Client/TransactionRetail">
      <IssueKeyedPreAuthResult>
        <ReferenceID>4706382</ReferenceID>
        <OrderNumber>1</OrderNumber>
        <TXDate>7/3/2009 2:05:04 AM</TXDate>
        <ApprovalStatus>APPROVED</ApprovalStatus>
        <AuthCode>VI0100</AuthCode>
        <CardHolder>Longbob Longsen</CardHolder>
        <Amount>1.00</Amount>
        <Type>5</Type>
        <CardNumber>************4242</CardNumber>
        <CardType>0</CardType>
        <AVSResponse>N</AVSResponse>
        <CVResponse>M</CVResponse>
        <POSEntryType>1</POSEntryType>
      </IssueKeyedPreAuthResult>
    </IssueKeyedPreAuthResponse>
  </soap:Body>
</soap:Envelope>
    XML
  end
  
  def fault_authorization_response
    <<-XML
<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <soap:Body>
    <soap:Fault>
      <faultcode>soap:Server</faultcode>
      <faultstring>Server was unable to process request. ---&gt; strPAN should be at least 13 to at most 19 characters in size.
Parameter name: strPAN</faultstring>
      <detail/>
    </soap:Fault>
  </soap:Body>
</soap:Envelope>
    XML
  end
  
  def failed_authorization_response
    <<-XML
<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <soap:Body>
    <IssueKeyedPreAuthResponse xmlns="http://merchantwarehouse.com/MerchantWARE/Client/TransactionRetail">
      <IssueKeyedPreAuthResult>
        <ReferenceID/>
        <OrderNumber>1</OrderNumber>
        <TXDate>7/3/2009 3:04:33 AM</TXDate>
        <ApprovalStatus>FAILED;1014;transaction type not supported by version</ApprovalStatus>
        <AuthCode/>
        <CardHolder>Longbob Longsen</CardHolder>
        <Amount>1.00</Amount>
        <Type>5</Type>
        <CardNumber>*********0123</CardNumber>
        <CardType>0</CardType>
        <AVSResponse/>
        <CVResponse/>
        <POSEntryType>1</POSEntryType>
      </IssueKeyedPreAuthResult>
    </IssueKeyedPreAuthResponse>
  </soap:Body>
</soap:Envelope>
    XML
  end
  
  def failed_void_response
    <<-XML
<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <soap:Body>
    <IssueVoidResponse xmlns="http://merchantwarehouse.com/MerchantWARE/Client/TransactionRetail">
      <IssueVoidResult>
        <ReferenceID>4707277</ReferenceID>
        <OrderNumber/>
        <TXDate>7/3/2009 3:28:38 AM</TXDate>
        <ApprovalStatus>DECLINED;1012;decline</ApprovalStatus>
        <AuthCode/>
        <CardHolder/>
        <Amount/>
        <Type>3</Type>
        <CardNumber/>
        <CardType>0</CardType>
        <AVSResponse/>
        <CVResponse/>
        <POSEntryType>0</POSEntryType>
      </IssueVoidResult>
    </IssueVoidResponse>
  </soap:Body>
</soap:Envelope>
    XML
  end
    
end
