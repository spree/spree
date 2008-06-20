require File.dirname(__FILE__) + '/../../test_helper'

class PsigateTest < Test::Unit::TestCase
  def setup
    @gateway = PsigateGateway.new(
      :login => 'teststore',
      :password => 'psigate1234'
    )

    @amount = 100
    @credit_card = credit_card('4111111111111111')
    @options = { :order_id => 1, :billing_address => address }
  end
  
  def test_successful_authorization
    @gateway.expects(:ssl_post).returns(successful_authorization_response)
    
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response
    assert_equal '1000', response.authorization
  end
  
  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response
    assert_equal '1000', response.authorization
  end
  
  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)
    
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
  end
   
  def test_amount_style
    assert_equal '10.34', @gateway.send(:amount, 1034)
  
    assert_raise(ArgumentError) do
      @gateway.send(:amount, '10.34')
    end
  end
    
  def test_supported_countries
    assert_equal ['CA'], PsigateGateway.supported_countries
  end
  
  def test_supported_card_types
    assert_equal [:visa, :master, :american_express], PsigateGateway.supported_cardtypes
  end
  
  def test_avs_result
    @gateway.expects(:ssl_post).returns(successful_authorization_response)
    
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'X', response.avs_result['code']
  end
  
  def test_cvv_result
    @gateway.expects(:ssl_post).returns(successful_authorization_response)
    
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'M', response.cvv_result['code']
  end
  
  private
  
  def successful_authorization_response
    <<-RESPONSE
<?xml version="1.0" encoding="UTF-8"?>
<Result>
  <TransTime>Sun Jan 06 23:10:53 EST 2008</TransTime>
  <OrderID>1000</OrderID>
  <TransactionType>PREAUTH</TransactionType>
  <Approved>APPROVED</Approved>
  <ReturnCode>Y:123456:0abcdef:M:X:NNN</ReturnCode>
  <ErrMsg/>
  <TaxTotal>0.00</TaxTotal>
  <ShipTotal>0.00</ShipTotal>
  <SubTotal>24.00</SubTotal>
  <FullTotal>24.00</FullTotal>
  <PaymentType>CC</PaymentType>
  <CardNumber>......4242</CardNumber>
  <TransRefNumber>1bdde305d7658367</TransRefNumber>
  <CardIDResult>M</CardIDResult>
  <AVSResult>X</AVSResult>
  <CardAuthNumber>123456</CardAuthNumber>
  <CardRefNumber>0abcdef</CardRefNumber>
  <CardType>VISA</CardType>
  <IPResult>NNN</IPResult>
  <IPCountry>UN</IPCountry>
  <IPRegion>UNKNOWN</IPRegion>
  <IPCity>UNKNOWN</IPCity>
</Result>
    RESPONSE
  end
  
  def successful_purchase_response
    <<-RESPONSE
<?xml version="1.0" encoding="UTF-8"?>
<Result>
  <TransTime>Sun Jan 06 23:15:30 EST 2008</TransTime>
  <OrderID>1000</OrderID>
  <TransactionType>SALE</TransactionType>
  <Approved>APPROVED</Approved>
  <ReturnCode>Y:123456:0abcdef:M:X:NNN</ReturnCode>
  <ErrMsg/>
  <TaxTotal>0.00</TaxTotal>
  <ShipTotal>0.00</ShipTotal>
  <SubTotal>24.00</SubTotal>
  <FullTotal>24.00</FullTotal>
  <PaymentType>CC</PaymentType>
  <CardNumber>......4242</CardNumber>
  <TransRefNumber>1bdde305da3ee234</TransRefNumber>
  <CardIDResult>M</CardIDResult>
  <AVSResult>X</AVSResult>
  <CardAuthNumber>123456</CardAuthNumber>
  <CardRefNumber>0abcdef</CardRefNumber>
  <CardType>VISA</CardType>
  <IPResult>NNN</IPResult>
  <IPCountry>UN</IPCountry>
  <IPRegion>UNKNOWN</IPRegion>
  <IPCity>UNKNOWN</IPCity>
</Result>
    RESPONSE
  end
  
  def failed_purchase_response
    <<-RESPONSE
<?xml version="1.0" encoding="UTF-8"?>
<Result>
  <TransTime>Sun Jan 06 23:24:29 EST 2008</TransTime>
  <OrderID>b3dca49e3ec77e42ab80a0f0f590fff0</OrderID>
  <TransactionType>SALE</TransactionType>
  <Approved>DECLINED</Approved>
  <ReturnCode>N:TESTDECLINE</ReturnCode>
  <ErrMsg/>
  <TaxTotal>0.00</TaxTotal>
  <ShipTotal>0.00</ShipTotal>
  <SubTotal>24.00</SubTotal>
  <FullTotal>24.00</FullTotal>
  <PaymentType>CC</PaymentType>
  <CardNumber>......4242</CardNumber>
  <TransRefNumber>1bdde305df991f89</TransRefNumber>
  <CardIDResult>M</CardIDResult>
  <AVSResult>X</AVSResult>
  <CardAuthNumber>TEST</CardAuthNumber>
  <CardRefNumber>TESTTRANS</CardRefNumber>
  <CardType>VISA</CardType>
  <IPResult>NNN</IPResult>
  <IPCountry>UN</IPCountry>
  <IPRegion>UNKNOWN</IPRegion>
  <IPCity>UNKNOWN</IPCity>
</Result>
    RESPONSE
  end
  
  def xml_purchase_fixture
    '<?xml version="1.0"?><Order><Bcity>New York</Bcity><OrderID>1004</OrderID><Bcountry>U.S.A.</Bcountry><CardAction>0</CardAction><Baddress1>123 fairweather Lane</Baddress1><StoreID>teststore</StoreID><Bprovince>NY</Bprovince><CardNumber>4111111111111111</CardNumber><PaymentType>CC</PaymentType><SubTotal>20.00</SubTotal><Passphrase>psigate1234</Passphrase><CardExpMonth>08</CardExpMonth><Baddress2>Apt B</Baddress2><Bpostalcode>10010</Bpostalcode><Bname>Longbob Longsen</Bname><CardExpYear>07</CardExpYear><Email>jack@yahoo.com</Email></Order>'
  end
  
  def xml_capture_fixture
    '<?xml version="1.0"?><Order><OrderID>1004</OrderID><CardAction>2</CardAction><StoreID>teststore</StoreID><PaymentType>CC</PaymentType><SubTotal>20.00</SubTotal><Passphrase>psigate1234</Passphrase></Order>'
  end
end