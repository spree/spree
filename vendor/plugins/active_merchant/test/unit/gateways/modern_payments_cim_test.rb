require 'test_helper'

class ModernPaymentsCimTest < Test::Unit::TestCase
  def setup
    Base.mode = :test
    
    @gateway = ModernPaymentsCimGateway.new(
                 :login => 'login',
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
  
  def test_create_customer
    @gateway.expects(:ssl_post).returns(successful_create_customer_response)
    
    assert response = @gateway.create_customer(@options)
    assert_instance_of Response, response
    assert response.test?
    assert_success response
    assert_equal "6677348", response.params["create_customer_result"]
  end
  
  def test_modify_customer_credit_card
    @gateway.expects(:ssl_post).returns(successful_modify_customer_credit_card_response)
    
    assert response = @gateway.modify_customer_credit_card("10001", @credit_card)
    assert_instance_of Response, response
    assert response.test?
    assert_success response
    assert_equal "6677757", response.params["modify_customer_credit_card_result"]
  end
  
  def test_successful_credit_card_authorization
    @gateway.expects(:ssl_post).returns(successful_credit_card_authorization_response)
    
    assert response = @gateway.authorize_credit_card_payment("10001", @amount)
    assert_instance_of Response, response
    assert response.test?
  
    assert_success response
    assert_equal "999", response.params["trans_id"]
    assert_equal "RESPONSECODE=A,AUTHCODE=XXXXXX,DECLINEREASON=,AVSDATA=NYZ,TRANSID=C00 TESTXXXXXXX", response.params["auth_string"]
    assert_equal "RESPONSECODE=A,AUTHCODE=XXXXXX,DECLINEREASON=,AVSDATA=NYZ,TRANSID=C00 TESTXXXXXXX", response.params["message_text"]
    assert_equal "false", response.params["approved"]
    assert_equal nil, response.params["avs_code"]
    assert_equal nil, response.params["auth_code"]
    assert_equal nil, response.params["trans_code"]
    assert_equal "999", response.authorization
    assert_match /RESPONSECODE=A/, response.params["message_text"]
  end
  
  def test_unsuccessful_credit_card_authorization
    @gateway.expects(:ssl_post).returns(unsuccessful_credit_card_authorization_response)
    
    assert response = @gateway.authorize_credit_card_payment("10001", @amount)
    assert_instance_of Response, response
    assert response.test?
    assert_success response
    assert_equal "999", response.authorization
    assert_match /RESPONSECODE=D/, response.params["message_text"]
  end
  
  def test_soap_fault_response
    @gateway.expects(:ssl_post).returns(soap_fault_response)
    
    assert response = @gateway.create_customer(@options)
    assert_instance_of Response, response
    assert response.test?
    assert_failure response
    assert_equal "soap:Client", response.params["faultcode"]
  end

  private
  
  def successful_create_customer_response
    <<-XML
<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <soap:Body>
    <CreateCustomerResponse xmlns="http://secure.modpay.com:81/ws/">
      <CreateCustomerResult>6677348</CreateCustomerResult>
    </CreateCustomerResponse>
  </soap:Body>
</soap:Envelope>
    XML
  end
  
  def successful_modify_customer_credit_card_response
    <<-XML
<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <soap:Body>
    <ModifyCustomerCreditCardResponse xmlns="http://secure.modpay.com:81/ws/">
      <ModifyCustomerCreditCardResult>6677757</ModifyCustomerCreditCardResult>
    </ModifyCustomerCreditCardResponse>
  </soap:Body>
</soap:Envelope>
    XML
  end
  
  def successful_credit_card_authorization_response
    <<-XML
<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
	<soap:Body>
		<AuthorizeCreditCardPaymentResponse xmlns="https://secure.modpay.com/netservices/test/">
			<AuthorizeCreditCardPaymentResult>
				<transId>999</transId>
				<authCode/>
				<avsCode/>
				<transCode/>
				<authString>RESPONSECODE=A,AUTHCODE=XXXXXX,DECLINEREASON=,AVSDATA=NYZ,TRANSID=C00 TESTXXXXXXX</authString>
				<messageText>RESPONSECODE=A,AUTHCODE=XXXXXX,DECLINEREASON=,AVSDATA=NYZ,TRANSID=C00 TESTXXXXXXX</messageText>
				<approved>false</approved>
			</AuthorizeCreditCardPaymentResult>
		</AuthorizeCreditCardPaymentResponse>
	</soap:Body>
</soap:Envelope>    
    XML
  end
  
  def unsuccessful_credit_card_authorization_response
    <<-XML
<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
	<soap:Body>
		<AuthorizeCreditCardPaymentResponse xmlns="https://secure.modpay.com/netservices/test/">
			<AuthorizeCreditCardPaymentResult>
				<transId>999</transId>
				<authCode/>
				<avsCode/>
				<transCode/>
				<authString>RESPONSECODE=D,AUTHCODE=,DECLINEREASON.1.TAG=,DECLINEREASON.1.ERRORCLASS=card declined,DECLINEREASON.1.PARAM1=05:DECLINE,DECLINEREASON.1.PARAM2=The authorization is declined,DECLINEREASON.1.MESSAGE=Card was declined: The authorization is declined,AVSDATA</authString>
				<messageText>RESPONSECODE=D,AUTHCODE=,DECLINEREASON.1.TAG=,DECLINEREASON.1.ERRORCLASS=card declined,DECLINEREASON.1.PARAM1=05:DECLINE,DECLINEREASON.1.PARAM2=The authorization is declined,DECLINEREASON.1.MESSAGE=Card was declined: The authorization is declined,AVSDATA</messageText>
				<approved>false</approved>
			</AuthorizeCreditCardPaymentResult>
		</AuthorizeCreditCardPaymentResponse>
	</soap:Body>
</soap:Envelope>    
    XML
  end
  
  def soap_fault_response
    <<-XML
<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <soap:Body>
    <soap:Fault>
      <faultcode>soap:Client</faultcode>
      <faultstring>System.Web.Services.Protocols.SoapException: Server did not recognize the value of HTTP Header SOAPAction: h heheheh http://secure.modpay.com:81/ws/CreateCustomer.
   at System.Web.Services.Protocols.Soap11ServerProtocolHelper.RouteRequest()
   at System.Web.Services.Protocols.SoapServerProtocol.RouteRequest(SoapServerMessage message)
   at System.Web.Services.Protocols.SoapServerProtocol.Initialize()
   at System.Web.Services.Protocols.ServerProtocolFactory.Create(Type type, HttpContext context, HttpRequest request, HttpResponse response, Boolean&amp; abortProcessing)</faultstring>
      <detail/>
    </soap:Fault>
  </soap:Body>
</soap:Envelope>
    XML
  end

end
