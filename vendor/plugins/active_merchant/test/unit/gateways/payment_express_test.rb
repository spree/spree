require File.dirname(__FILE__) + '/../../test_helper'

class PaymentExpressTest < Test::Unit::TestCase
  def setup
        
    @gateway = PaymentExpressGateway.new(
      :login => 'LOGIN',
      :password => 'PASSWORD'
    )

    @visa = credit_card
    
    @solo = credit_card("6334900000000005",
              :type   => "solo",
              :issue_number => '01'
            )

    @options = { 
      :order_id => generate_unique_id,
      :billing_address => address,
      :email => 'cody@example.com',
      :description => 'Store purchase'
    }
    
    @amount = 100
  end
  
  def test_default_currency
    assert_equal 'NZD', PaymentExpressGateway.default_currency
  end
  
  def test_invalid_credentials
    @gateway.expects(:ssl_post).returns(invalid_credentials_response)
    
    assert response = @gateway.purchase(@amount, @visa, @options)
    assert_equal 'Invalid Credentials', response.message
    assert_failure response
  end
  
  def test_successful_authorization
     @gateway.expects(:ssl_post).returns(successful_authorization_response)

     assert response = @gateway.purchase(@amount, @visa, @options)
     assert_success response
     assert response.test?
     assert_equal 'APPROVED', response.message
     assert_equal '00000004011a2478', response.authorization
  end
  
  def test_successful_solo_authorization
    @gateway.expects(:ssl_post).returns(successful_authorization_response)

     assert response = @gateway.purchase(@amount, @solo, @options)
     assert_success response
     assert response.test?
     assert_equal 'APPROVED', response.message
     assert_equal '00000004011a2478', response.authorization
  end
  
  def test_successful_card_store
    @gateway.expects(:ssl_post).returns( successful_store_response )
    
    assert response = @gateway.store(@visa)
    assert_success response
    assert response.test?
    assert_equal '0000030000141581', response.token        
  end
  
  def test_successful_card_store_with_custom_billing_id
    @gateway.expects(:ssl_post).returns( successful_store_response(:billing_id => "my-custom-id") )
    
    assert response = @gateway.store(@visa, :billing_id => "my-custom-id")
    assert_success response
    assert response.test?
    assert_equal 'my-custom-id', response.token
  end
  
  def test_unsuccessful_card_store
    @gateway.expects(:ssl_post).returns( unsuccessful_store_response )
    
    @visa.number = 2
    
    assert response = @gateway.store(@visa)
    assert_failure response
  end
  
  def test_purchase_using_token
    @gateway.expects(:ssl_post).returns( successful_store_response )
    
    assert response = @gateway.store(@visa)
    token = response.token
    
    @gateway.expects(:ssl_post).returns( successful_token_purchase_response )
    
    assert response = @gateway.purchase(@amount, token, @options)
    assert_success response
    assert_equal 'APPROVED', response.message
    assert_equal '0000000303ace8db', response.authorization
  end
  
  def test_supported_countries
     assert_equal ['AU','MY','NZ','SG','ZA','GB','US'], PaymentExpressGateway.supported_countries
   end

  def test_supported_card_types
   assert_equal [ :visa, :master, :american_express, :diners_club, :jcb ], PaymentExpressGateway.supported_cardtypes
  end
  
  def test_avs_result_not_supported
    @gateway.expects(:ssl_post).returns(successful_authorization_response)
    
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_nil response.avs_result['code']
  end
  
  def test_cvv_result_not_supported
    @gateway.expects(:ssl_post).returns(successful_authorization_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_nil response.cvv_result['code']
  end
  
  private
  def invalid_credentials_response
    '<Txn><ReCo>0</ReCo><ResponseText>Invalid Credentials</ResponseText></Txn>'
  end
    
  def successful_authorization_response
    <<-RESPONSE
<Txn>
  <Transaction success="1" reco="00" responsetext="APPROVED">
    <Authorized>1</Authorized>
    <MerchantReference>Test Transaction</MerchantReference>
    <Cvc2>M</Cvc2>
    <CardName>Visa</CardName>
    <Retry>0</Retry>
    <StatusRequired>0</StatusRequired>
    <AuthCode>015921</AuthCode>
    <Amount>1.23</Amount>
    <InputCurrencyId>1</InputCurrencyId>
    <InputCurrencyName>NZD</InputCurrencyName>
    <Acquirer>WestpacTrust</Acquirer>
    <CurrencyId>1</CurrencyId>
    <CurrencyName>NZD</CurrencyName>
    <CurrencyRate>1.00</CurrencyRate>
    <Acquirer>WestpacTrust</Acquirer>
    <AcquirerDate>30102000</AcquirerDate>
    <AcquirerId>1</AcquirerId>
    <CardHolderName>DPS</CardHolderName>
    <DateSettlement>20050811</DateSettlement>
    <TxnType>Purchase</TxnType>
    <CardNumber>411111</CardNumber>
    <DateExpiry>0807</DateExpiry>
    <ProductId></ProductId>
    <AcquirerDate>20050811</AcquirerDate>
    <AcquirerTime>060039</AcquirerTime>
    <AcquirerId>9000</AcquirerId>
    <Acquirer>Test</Acquirer>
    <TestMode>1</TestMode>
    <CardId>2</CardId>
    <CardHolderResponseText>APPROVED</CardHolderResponseText>
    <CardHolderHelpText>The Transaction was approved</CardHolderHelpText>
    <CardHolderResponseDescription>The Transaction was approved</CardHolderResponseDescription>
    <MerchantResponseText>APPROVED</MerchantResponseText>
    <MerchantHelpText>The Transaction was approved</MerchantHelpText>
    <MerchantResponseDescription>The Transaction was approved</MerchantResponseDescription>
    <GroupAccount>9997</GroupAccount>
    <DpsTxnRef>00000004011a2478</DpsTxnRef>
    <AllowRetry>0</AllowRetry>
    <DpsBillingId></DpsBillingId>
    <BillingId></BillingId>
    <TransactionId>011a2478</TransactionId>
  </Transaction>
  <ReCo>00</ReCo>
  <ResponseText>APPROVED</ResponseText>
  <HelpText>The Transaction was approved</HelpText>
  <Success>1</Success>
  <TxnRef>00000004011a2478</TxnRef>
</Txn>
    RESPONSE
  end
  
  def successful_store_response(options = {})
    %(<Txn><Transaction success="1" reco="00" responsetext="APPROVED"><Authorized>1</Authorized><MerchantReference></MerchantReference><CardName>Visa</CardName><Retry>0</Retry><StatusRequired>0</StatusRequired><AuthCode>02381203accf5c00000003</AuthCode><Amount>0.01</Amount><CurrencyId>554</CurrencyId><InputCurrencyId>554</InputCurrencyId><InputCurrencyName>NZD</InputCurrencyName><CurrencyRate>1.00</CurrencyRate><CurrencyName>NZD</CurrencyName><CardHolderName>BOB BOBSEN</CardHolderName><DateSettlement>20070323</DateSettlement><TxnType>Auth</TxnType><CardNumber>424242........42</CardNumber><DateExpiry>0809</DateExpiry><ProductId></ProductId><AcquirerDate>20070323</AcquirerDate><AcquirerTime>023812</AcquirerTime><AcquirerId>9000</AcquirerId><Acquirer>Test</Acquirer><TestMode>1</TestMode><CardId>2</CardId><CardHolderResponseText>APPROVED</CardHolderResponseText><CardHolderHelpText>The Transaction was approved</CardHolderHelpText><CardHolderResponseDescription>The Transaction was approved</CardHolderResponseDescription><MerchantResponseText>APPROVED</MerchantResponseText><MerchantHelpText>The Transaction was approved</MerchantHelpText><MerchantResponseDescription>The Transaction was approved</MerchantResponseDescription><UrlFail></UrlFail><UrlSuccess></UrlSuccess><EnablePostResponse>0</EnablePostResponse><PxPayName></PxPayName><PxPayLogoSrc></PxPayLogoSrc><PxPayUserId></PxPayUserId><PxPayXsl></PxPayXsl><PxPayBgColor></PxPayBgColor><AcquirerPort>9999999999-99999999</AcquirerPort><AcquirerTxnRef>12835</AcquirerTxnRef><GroupAccount>9997</GroupAccount><DpsTxnRef>0000000303accf5c</DpsTxnRef><AllowRetry>0</AllowRetry><DpsBillingId>0000030000141581</DpsBillingId><BillingId>#{options[:billing_id]}</BillingId><TransactionId>03accf5c</TransactionId><PxHostId>00000003</PxHostId></Transaction><ReCo>00</ReCo><ResponseText>APPROVED</ResponseText><HelpText>The Transaction was approved</HelpText><Success>1</Success><DpsTxnRef>0000000303accf5c</DpsTxnRef><TxnRef></TxnRef></Txn>)
  end
  
  def unsuccessful_store_response(options = {})
    %(<Txn><Transaction success="0" reco="QK" responsetext="INVALID CARD NUMBER"><Authorized>0</Authorized><MerchantReference></MerchantReference><CardName></CardName><Retry>0</Retry><StatusRequired>0</StatusRequired><AuthCode></AuthCode><Amount>0.01</Amount><CurrencyId>554</CurrencyId><InputCurrencyId>554</InputCurrencyId><InputCurrencyName>NZD</InputCurrencyName><CurrencyRate>1.00</CurrencyRate><CurrencyName>NZD</CurrencyName><CardHolderName>LONGBOB LONGSEN</CardHolderName><DateSettlement>19800101</DateSettlement><TxnType>Validate</TxnType><CardNumber>000000........00</CardNumber><DateExpiry>0808</DateExpiry><ProductId></ProductId><AcquirerDate></AcquirerDate><AcquirerTime></AcquirerTime><AcquirerId>9000</AcquirerId><Acquirer></Acquirer><TestMode>0</TestMode><CardId>0</CardId><CardHolderResponseText>INVALID CARD NUMBER</CardHolderResponseText><CardHolderHelpText>An Invalid Card Number was entered. Check the card number</CardHolderHelpText><CardHolderResponseDescription>An Invalid Card Number was entered. Check the card number</CardHolderResponseDescription><MerchantResponseText>INVALID CARD NUMBER</MerchantResponseText><MerchantHelpText>An Invalid Card Number was entered. Check the card number</MerchantHelpText><MerchantResponseDescription>An Invalid Card Number was entered. Check the card number</MerchantResponseDescription><UrlFail></UrlFail><UrlSuccess></UrlSuccess><EnablePostResponse>0</EnablePostResponse><PxPayName></PxPayName><PxPayLogoSrc></PxPayLogoSrc><PxPayUserId></PxPayUserId><PxPayXsl></PxPayXsl><PxPayBgColor></PxPayBgColor><AcquirerPort>9999999999-99999999</AcquirerPort><AcquirerTxnRef>0</AcquirerTxnRef><GroupAccount>9997</GroupAccount><DpsTxnRef></DpsTxnRef><AllowRetry>0</AllowRetry><DpsBillingId></DpsBillingId><BillingId></BillingId><TransactionId>00000000</TransactionId><PxHostId>00000003</PxHostId></Transaction><ReCo>QK</ReCo><ResponseText>INVALID CARD NUMBER</ResponseText><HelpText>An Invalid Card Number was entered. Check the card number</HelpText><Success>0</Success><DpsTxnRef></DpsTxnRef><TxnRef></TxnRef></Txn>)
  end
  
  def successful_token_purchase_response
    %(<Txn><Transaction success="1" reco="00" responsetext="APPROVED"><Authorized>1</Authorized><MerchantReference></MerchantReference><CardName>Visa</CardName><Retry>0</Retry><StatusRequired>0</StatusRequired><AuthCode>030817</AuthCode><Amount>10.00</Amount><CurrencyId>554</CurrencyId><InputCurrencyId>554</InputCurrencyId><InputCurrencyName>NZD</InputCurrencyName><CurrencyRate>1.00</CurrencyRate><CurrencyName>NZD</CurrencyName><CardHolderName>LONGBOB LONGSEN</CardHolderName><DateSettlement>20070323</DateSettlement><TxnType>Purchase</TxnType><CardNumber>424242........42</CardNumber><DateExpiry>0808</DateExpiry><ProductId></ProductId><AcquirerDate>20070323</AcquirerDate><AcquirerTime>030817</AcquirerTime><AcquirerId>9000</AcquirerId><Acquirer>Test</Acquirer><TestMode>1</TestMode><CardId>2</CardId><CardHolderResponseText>APPROVED</CardHolderResponseText><CardHolderHelpText>The Transaction was approved</CardHolderHelpText><CardHolderResponseDescription>The Transaction was approved</CardHolderResponseDescription><MerchantResponseText>APPROVED</MerchantResponseText><MerchantHelpText>The Transaction was approved</MerchantHelpText><MerchantResponseDescription>The Transaction was approved</MerchantResponseDescription><UrlFail></UrlFail><UrlSuccess></UrlSuccess><EnablePostResponse>0</EnablePostResponse><PxPayName></PxPayName><PxPayLogoSrc></PxPayLogoSrc><PxPayUserId></PxPayUserId><PxPayXsl></PxPayXsl><PxPayBgColor></PxPayBgColor><AcquirerPort>9999999999-99999999</AcquirerPort><AcquirerTxnRef>12859</AcquirerTxnRef><GroupAccount>9997</GroupAccount><DpsTxnRef>0000000303ace8db</DpsTxnRef><AllowRetry>0</AllowRetry><DpsBillingId>0000030000141581</DpsBillingId><BillingId></BillingId><TransactionId>03ace8db</TransactionId><PxHostId>00000003</PxHostId></Transaction><ReCo>00</ReCo><ResponseText>APPROVED</ResponseText><HelpText>The Transaction was approved</HelpText><Success>1</Success><DpsTxnRef>0000000303ace8db</DpsTxnRef><TxnRef></TxnRef></Txn>)
  end
  
end
