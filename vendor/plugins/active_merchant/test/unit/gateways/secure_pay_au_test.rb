require 'test_helper'

class SecurePayAuTest < Test::Unit::TestCase
  def setup
    @gateway = SecurePayAuGateway.new(
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
  
  def test_successful_purchase_with_live_data
    @gateway.expects(:ssl_post).returns(successful_live_purchase_response)
    
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response
    
    assert_equal '000000', response.authorization
    assert response.test?
  end
  
  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response
    
    assert_equal '024259', response.authorization
    assert response.test?
  end

  def test_unsuccessful_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)
    
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_failure response
    assert response.test?
    assert_equal "CARD EXPIRED", response.message
  end
  
  def test_failed_login
    @gateway.expects(:ssl_post).returns(failed_login_response)
    
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_failure response
    assert_equal "Invalid merchant ID", response.message
  end

  private
  
  def failed_login_response
    '<SecurePayMessage><Status><statusCode>504</statusCode><statusDescription>Invalid merchant ID</statusDescription></Status></SecurePayMessage>'
  end
  
  def successful_purchase_response
    <<-XML
<?xml version="1.0" encoding="UTF-8"?>
<SecurePayMessage>
  <MessageInfo>
    <messageID>8af793f9af34bea0cf40f5fb5c630c</messageID>
    <messageTimestamp>20080802041625665000+660</messageTimestamp>
    <apiVersion>xml-4.2</apiVersion>
  </MessageInfo>
  <RequestType>Payment</RequestType>
  <MerchantInfo>
    <merchantID>XYZ0001</merchantID>
  </MerchantInfo>
  <Status>
    <statusCode>000</statusCode>
    <statusDescription>Normal</statusDescription>
  </Status>
  <Payment>
    <TxnList count="1">
      <Txn ID="1">
        <txnType>0</txnType>
        <txnSource>0</txnSource>
        <amount>1000</amount>
        <currency>AUD</currency>
        <purchaseOrderNo>test</purchaseOrderNo>
        <approved>Yes</approved>
        <responseCode>00</responseCode>
        <responseText>Approved</responseText>
        <thinlinkResponseCode>100</thinlinkResponseCode>
        <thinlinkResponseText>000</thinlinkResponseText>
        <thinlinkEventStatusCode>000</thinlinkEventStatusCode>
        <thinlinkEventStatusText>Normal</thinlinkEventStatusText>
        <settlementDate>20080208</settlementDate>
        <txnID>024259</txnID>
        <CreditCardInfo>
          <pan>424242...242</pan>
          <expiryDate>07/11</expiryDate>
          <cardType>6</cardType>
          <cardDescription>Visa</cardDescription>
        </CreditCardInfo>
      </Txn>
    </TxnList>
  </Payment>
</SecurePayMessage>
    XML
  end
  
  def failed_purchase_response
    <<-XML
<?xml version="1.0" encoding="UTF-8"?>
<SecurePayMessage>
  <MessageInfo>
    <messageID>8af793f9af34bea0cf40f5fb5c630c</messageID>
    <messageTimestamp>20080802040346380000+660</messageTimestamp>
    <apiVersion>xml-4.2</apiVersion>
  </MessageInfo>
  <RequestType>Payment</RequestType>
  <MerchantInfo>
    <merchantID>XYZ0001</merchantID>
  </MerchantInfo>
  <Status>
    <statusCode>000</statusCode>
    <statusDescription>Normal</statusDescription>
  </Status>
  <Payment>
    <TxnList count="1">
      <Txn ID="1">
        <txnType>0</txnType>
        <txnSource>0</txnSource>
        <amount>1000</amount>
        <currency>AUD</currency>
        <purchaseOrderNo>test</purchaseOrderNo>
        <approved>No</approved>
        <responseCode>907</responseCode>
        <responseText>CARD EXPIRED</responseText>
        <thinlinkResponseCode>300</thinlinkResponseCode>
        <thinlinkResponseText>000</thinlinkResponseText>
        <thinlinkEventStatusCode>981</thinlinkEventStatusCode>
        <thinlinkEventStatusText>Error - Expired Card</thinlinkEventStatusText>
        <settlementDate>        </settlementDate>
        <txnID>000000</txnID>
        <CreditCardInfo>
          <pan>424242...242</pan>
          <expiryDate>07/06</expiryDate>
          <cardType>6</cardType>
          <cardDescription>Visa</cardDescription>
        </CreditCardInfo>
      </Txn>
    </TxnList>
  </Payment>
</SecurePayMessage>
    XML
  end
  
  def successful_live_purchase_response
    <<-XML
    <?xml version="1.0" encoding="UTF-8"?>
    <SecurePayMessage>
      <MessageInfo>
        <messageID>8af793f9af34bea0cf40f5fb5c630c</messageID>
        <messageTimestamp>20080802041625665000+660</messageTimestamp>
        <apiVersion>xml-4.2</apiVersion>
      </MessageInfo>
      <RequestType>Payment</RequestType>
      <MerchantInfo>
        <merchantID>XYZ0001</merchantID>
      </MerchantInfo>
      <Status>
        <statusCode>000</statusCode>
        <statusDescription>Normal</statusDescription>
      </Status>
      <Payment>
        <TxnList count="1">
          <Txn ID="1">
            <txnType>0</txnType>
            <txnSource>23</txnSource>
            <amount>211700</amount>
            <currency>AUD</currency>
            <purchaseOrderNo>#1047.5</purchaseOrderNo>
            <approved>Yes</approved>
            <responseCode>77</responseCode>
            <responseText>Approved</responseText>
            <thinlinkResponseCode>100</thinlinkResponseCode>
            <thinlinkResponseText>000</thinlinkResponseText>
            <thinlinkEventStatusCode>000</thinlinkEventStatusCode>
            <thinlinkEventStatusText>Normal</thinlinkEventStatusText>
            <settlementDate>20080525</settlementDate>
            <txnID>000000</txnID>
            <CreditCardInfo>
              <pan>424242...242</pan>
              <expiryDate>07/11</expiryDate>
              <cardType>6</cardType>
              <cardDescription>Visa</cardDescription>
            </CreditCardInfo>
          </Txn>
        </TxnList>
      </Payment>
    </SecurePayMessage>
    XML
  end
end
