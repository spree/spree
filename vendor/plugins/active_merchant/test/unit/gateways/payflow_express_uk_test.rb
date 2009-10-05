require 'test_helper'

class PayflowExpressUkTest < Test::Unit::TestCase
  def setup
    @gateway = PayflowExpressUkGateway.new(
      :login => 'LOGIN',
      :password => 'PASSWORD'
    )
  end
  
  def test_supported_countries
    assert_equal ['GB'], PayflowExpressUkGateway.supported_countries
  end
  
  def test_get_express_details
     @gateway.expects(:ssl_post).returns(successful_get_express_details_response)
     response = @gateway.details_for('EC-2OPN7UJGFWK9OYFV')
     assert_instance_of PayflowExpressResponse, response
     assert_success response
     assert response.test?

     assert_equal 'EC-2OPN7UJGFWK9OYFV', response.token
     assert_equal 'LYWCMEN4FA7ZQ', response.payer_id
     assert_equal 'paul@test.com', response.email
     assert_equal 'paul smith', response.full_name
     assert_equal 'GB', response.payer_country

     assert address = response.address
     assert_equal 'paul smith', address['name']
     assert_nil address['company']
     assert_equal '10 keyworth avenue', address['address1']
     assert_equal 'grangetown', address['address2']
     assert_equal 'hinterland', address['city']
     assert_equal 'Tyne and Wear', address['state']
     assert_equal 'sr5 2uh', address['zip']
     assert_equal 'GB', address['country']
     assert_nil address['phone']
   end
  
  private
  def successful_get_express_details_response
    <<-RESPONSE
<?xml version="1.0"?>
<XMLPayResponse xmlns="http://www.paypal.com/XMLPay">
  <ResponseData>
    <Vendor>markcoop</Vendor>
    <Partner>paypaluk</Partner>
    <TransactionResults>
      <TransactionResult>
        <Result>0</Result>
        <AVSResult>
          <StreetMatch>Match</StreetMatch>
          <ZipMatch>Match</ZipMatch>
        </AVSResult>
        <Message>Approved</Message>
        <PayPalResult>
          <EMail>paul@test.com</EMail>
          <PayerID>LYWCMEN4FA7ZQ</PayerID>
          <Token>EC-2OPN7UJGFWK9OYFV</Token>
          <FeeAmount>0</FeeAmount>
          <PayerStatus>unverified</PayerStatus>
          <Name>paul</Name>
          <ShipTo>
            <Address>
              <Street>10 keyworth avenue</Street>
              <City>hinterland</City>
              <State>Tyne and Wear</State>
              <Zip>sr5 2uh</Zip>
              <Country>GB</Country>
            </Address>
          </ShipTo>
          <CorrelationID>1ea22ef3873ba</CorrelationID>
        </PayPalResult>
        <ExtData Name="LASTNAME" Value="smith"/>
        <ExtData Name="SHIPTOSTREET2" Value="grangetown"/>
        <ExtData Name="SHIPTONAME" Value="paul smith"/>
        <ExtData Name="STREET2" Value="ALLAWAY AVENUE"/>
        <ExtData Name="COUNTRYCODE" Value="GB"/>
        <ExtData Name="ADDRESSSTATUS" Value="Y"/>
      </TransactionResult>
    </TransactionResults>
  </ResponseData>
</XMLPayResponse>
    RESPONSE
  end
end
