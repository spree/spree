require File.dirname(__FILE__) + '/../../test_helper'

class ExactTest < Test::Unit::TestCase
  def setup
    @gateway = ExactGateway.new( :login    => "A00427-01",
                                 :password => "testus" )

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
    assert_equal 'ET1700;106625152', response.authorization
    assert response.test?
    assert_equal 'Transaction Normal - VER UNAVAILABLE', response.message
    
    ExactGateway::SENSITIVE_FIELDS.each{ |f| assert !response.params.has_key?(f.to_s) }
  end
  
  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)
  
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_failure response
  end
  

  def test_expdate
    assert_equal( "%02d%s" % [ @credit_card.month,
                               @credit_card.year.to_s[-2..-1] ],
                  @gateway.send(:expdate, @credit_card) )
  end
    
  def test_soap_fault
    @gateway.expects(:ssl_post).returns(soap_fault_response)
    assert response = @gateway.purchase(100, @credit_card, {})
    assert_failure response
    assert response.test?
    assert_equal 'Unable to handle request without a valid action parameter. Please supply a valid soap action.', response.message
  end
  
  def test_supported_countries
    assert_equal ['CA', 'US'], ExactGateway.supported_countries
  end
  
  def test_supported_card_types
    assert_equal [:visa, :master, :american_express, :jcb, :discover], ExactGateway.supported_cardtypes
  end
  
  def test_avs_result
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    
    response = @gateway.purchase(@amount, @credit_card)
    assert_equal 'U', response.avs_result['code']
  end
  
  def test_cvv_result
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    
    response = @gateway.purchase(@amount, @credit_card)
    assert_equal 'M', response.cvv_result['code']
  end
  
  
  private
  def successful_purchase_response
    <<-RESPONSE
<?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/" xmlns:tns="http://secure2.e-xact.com/vplug-in/transaction/rpc-enc/" xmlns:types="http://secure2.e-xact.com/vplug-in/transaction/rpc-enc/encodedTypes" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"><soap:Body soap:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><q1:SendAndCommitResponse xmlns:q1="http://secure2.e-xact.com/vplug-in/transaction/rpc-enc/Response"><SendAndCommitResult href="#id1" /></q1:SendAndCommitResponse><types:TransactionResult id="id1" xsi:type="types:TransactionResult"><ExactID xsi:type="xsd:string">A00427-01</ExactID><Password xsi:type="xsd:string">#######</Password><Transaction_Type xsi:type="xsd:string">00</Transaction_Type><DollarAmount xsi:type="xsd:string">1</DollarAmount><SurchargeAmount xsi:type="xsd:string">0</SurchargeAmount><Card_Number xsi:type="xsd:string">4242424242424242</Card_Number><Transaction_Tag xsi:type="xsd:string">106625152</Transaction_Tag><Authorization_Num xsi:type="xsd:string">ET1700</Authorization_Num><Expiry_Date xsi:type="xsd:string">0909</Expiry_Date><CardHoldersName xsi:type="xsd:string">Longbob Longsen</CardHoldersName><VerificationStr2 xsi:type="xsd:string">123</VerificationStr2><CVD_Presence_Ind xsi:type="xsd:string">1</CVD_Presence_Ind><Secure_AuthRequired xsi:type="xsd:string">0</Secure_AuthRequired><Secure_AuthResult xsi:type="xsd:string">0</Secure_AuthResult><Ecommerce_Flag xsi:type="xsd:string">0</Ecommerce_Flag><CAVV_Algorithm xsi:type="xsd:string">0</CAVV_Algorithm><Reference_No xsi:type="xsd:string">1</Reference_No><Reference_3 xsi:type="xsd:string">Store Purchase</Reference_3><Language xsi:type="xsd:string">0</Language><LogonMessage xsi:type="xsd:string">Processed by: 
E-xact Transaction Gateway :- Version 8.4.0 B19b 
Copyright 2006 
{34:2652}</LogonMessage><Error_Number xsi:type="xsd:string">0</Error_Number><Error_Description xsi:type="xsd:string" /><Transaction_Error xsi:type="xsd:boolean">false</Transaction_Error><Transaction_Approved xsi:type="xsd:boolean">true</Transaction_Approved><EXact_Resp_Code xsi:type="xsd:string">00</EXact_Resp_Code><EXact_Message xsi:type="xsd:string">Transaction Normal</EXact_Message><Bank_Resp_Code xsi:type="xsd:string">00</Bank_Resp_Code><Bank_Message xsi:type="xsd:string">VER UNAVAILABLE </Bank_Message><SequenceNo xsi:type="xsd:string">377</SequenceNo><AVS xsi:type="xsd:string">U</AVS><CVV2 xsi:type="xsd:string">M</CVV2><Retrieval_Ref_No xsi:type="xsd:string">200801181700</Retrieval_Ref_No><MerchantName xsi:type="xsd:string">E-xact ConnectionShop</MerchantName><MerchantAddress xsi:type="xsd:string">Suite 400 - 1152 Mainland St.</MerchantAddress><MerchantCity xsi:type="xsd:string">Vancouver</MerchantCity><MerchantProvince xsi:type="xsd:string">BC</MerchantProvince><MerchantCountry xsi:type="xsd:string">Canada</MerchantCountry><MerchantPostal xsi:type="xsd:string">V6B 4X2</MerchantPostal><MerchantURL xsi:type="xsd:string">www.e-xact.com</MerchantURL><CTR xsi:type="xsd:string">========== TRANSACTION RECORD ========= 
  
E-xact ConnectionShop 
Suite 400 - 1152 Mainland St. 
Vancouver, BC V6B 4X2 
www.e-xact.com 
  
TYPE: Purchase 
  
ACCT: Visa             $1.00 USD 
  
CARD NUMBER : ############4242 
TRANS. REF. : 1 
CARD HOLDER : Longbob Longsen 
EXPIRY DATE : xx/xx 
DATE/TIME   : 18 Jan 08 14:17:00 
REFERENCE # : 5999 377 M 
AUTHOR.#    : ET1700 
  
      Approved - Thank You 00 
  
SIGNATURE 



_______________________________________ 

</CTR></types:TransactionResult></soap:Body></soap:Envelope>
    RESPONSE
  end
  
  def failed_purchase_response
    <<-RESPONSE
<?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/" xmlns:tns="http://secure2.e-xact.com/vplug-in/transaction/rpc-enc/" xmlns:types="http://secure2.e-xact.com/vplug-in/transaction/rpc-enc/encodedTypes" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"><soap:Body soap:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><q1:SendAndCommitResponse xmlns:q1="http://secure2.e-xact.com/vplug-in/transaction/rpc-enc/Response"><SendAndCommitResult href="#id1" /></q1:SendAndCommitResponse><types:TransactionResult id="id1" xsi:type="types:TransactionResult"><ExactID xsi:type="xsd:string">A00427-01</ExactID><Password xsi:type="xsd:string">#######</Password><Transaction_Type xsi:type="xsd:string">00</Transaction_Type><DollarAmount xsi:type="xsd:string">5013</DollarAmount><SurchargeAmount xsi:type="xsd:string">0</SurchargeAmount><Card_Number xsi:type="xsd:string">4111111111111111</Card_Number><Transaction_Tag xsi:type="xsd:string">106624668</Transaction_Tag><Expiry_Date xsi:type="xsd:string">0909</Expiry_Date><CardHoldersName xsi:type="xsd:string">Longbob Longsen</CardHoldersName><VerificationStr2 xsi:type="xsd:string">123</VerificationStr2><CVD_Presence_Ind xsi:type="xsd:string">1</CVD_Presence_Ind><Secure_AuthRequired xsi:type="xsd:string">0</Secure_AuthRequired><Secure_AuthResult xsi:type="xsd:string">0</Secure_AuthResult><Ecommerce_Flag xsi:type="xsd:string">0</Ecommerce_Flag><CAVV_Algorithm xsi:type="xsd:string">0</CAVV_Algorithm><Reference_No xsi:type="xsd:string">1</Reference_No><Reference_3 xsi:type="xsd:string">Store Purchase</Reference_3><Language xsi:type="xsd:string">0</Language><LogonMessage xsi:type="xsd:string">Processed by: 
E-xact Transaction Gateway :- Version 8.4.0 B19b 
Copyright 2006 
{34:2652}</LogonMessage><Error_Number xsi:type="xsd:string">0</Error_Number><Error_Description xsi:type="xsd:string" /><Transaction_Error xsi:type="xsd:boolean">false</Transaction_Error><Transaction_Approved xsi:type="xsd:boolean">false</Transaction_Approved><EXact_Resp_Code xsi:type="xsd:string">00</EXact_Resp_Code><EXact_Message xsi:type="xsd:string">Transaction Normal</EXact_Message><Bank_Resp_Code xsi:type="xsd:string">13</Bank_Resp_Code><Bank_Message xsi:type="xsd:string">AMOUNT ERR</Bank_Message><SequenceNo xsi:type="xsd:string">376</SequenceNo><AVS xsi:type="xsd:string">U</AVS><CVV2 xsi:type="xsd:string">M</CVV2><MerchantName xsi:type="xsd:string">E-xact ConnectionShop</MerchantName><MerchantAddress xsi:type="xsd:string">Suite 400 - 1152 Mainland St.</MerchantAddress><MerchantCity xsi:type="xsd:string">Vancouver</MerchantCity><MerchantProvince xsi:type="xsd:string">BC</MerchantProvince><MerchantCountry xsi:type="xsd:string">Canada</MerchantCountry><MerchantPostal xsi:type="xsd:string">V6B 4X2</MerchantPostal><MerchantURL xsi:type="xsd:string">www.e-xact.com</MerchantURL><CTR xsi:type="xsd:string">========== TRANSACTION RECORD ========= 
  
E-xact ConnectionShop 
Suite 400 - 1152 Mainland St. 
Vancouver, BC V6B 4X2 
www.e-xact.com 
  
TYPE: Purchase 
  
ACCT: Visa             $5,013.00 USD 
  
CARD NUMBER : ############1111 
TRANS. REF. : 1 
CARD HOLDER : Longbob Longsen 
EXPIRY DATE : xx/xx 
DATE/TIME   : 18 Jan 08 14:11:09 
REFERENCE # : 5999 376 M 
AUTHOR.#    : 
  
      Transaction not Approved 13 
  

</CTR></types:TransactionResult></soap:Body></soap:Envelope>    
    RESPONSE
  end

  def soap_fault_response
    <<-RESPONSE
<?xml version='1.0' encoding='UTF-8'?>
<soap:Envelope xmlns:soap='http://schemas.xmlsoap.org/soap/envelope/' xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance' xmlns:xsd='http://www.w3.org/2001/XMLSchema'>
  <soap:Body>
    <soap:Fault>
      <faultcode>soap:Client</faultcode>
      <faultstring>Unable to handle request without a valid action parameter. Please supply a valid soap action.</faultstring>
      <detail/>
    </soap:Fault>
  </soap:Body>
</soap:Envelope>
    RESPONSE
  end
end