require 'test_helper'

class PayflowExpressTest < Test::Unit::TestCase
  TEST_REDIRECT_URL = 'https://test-expresscheckout.paypal.com/cgi-bin/webscr?cmd=_express-checkout&token=1234567890'
  LIVE_REDIRECT_URL = 'https://www.paypal.com/cgibin/webscr?cmd=_express-checkout&token=1234567890'
  
  TEST_REDIRECT_URL_WITHOUT_REVIEW = "#{TEST_REDIRECT_URL}&useraction=commit"
  LIVE_REDIRECT_URL_WITHOUT_REVIEW = "#{LIVE_REDIRECT_URL}&useraction=commit"
  
  def setup
    Base.gateway_mode = :test
  
    @gateway = PayflowExpressGateway.new(
      :login => 'LOGIN',
      :password => 'PASSWORD'
    )

    @address = { :address1 => '1234 My Street',
                 :address2 => 'Apt 1',
                 :company => 'Widgets Inc',
                 :city => 'Ottawa',
                 :state => 'ON',
                 :zip => 'K1C2N6',
                 :country => 'Canada',
                 :phone => '(555)555-5555'
               }
  end
  
  def teardown
    Base.gateway_mode = :test
  end
  
  def test_using_test_mode
    assert @gateway.test?
  end
  
  def test_overriding_test_mode
    Base.gateway_mode = :production
    
    gateway = PayflowExpressGateway.new(
      :login => 'LOGIN',
      :password => 'PASSWORD',
      :test => true
    )
    
    assert gateway.test?
  end
  
  def test_using_production_mode
    Base.gateway_mode = :production
    
    gateway = PayflowExpressGateway.new(
      :login => 'LOGIN',
      :password => 'PASSWORD'
    )
    
    assert !gateway.test?
  end
  
  def test_live_redirect_url
    Base.gateway_mode = :production
    assert_equal LIVE_REDIRECT_URL, @gateway.redirect_url_for('1234567890')
  end
  
  def test_test_redirect_url
    assert_equal TEST_REDIRECT_URL, @gateway.redirect_url_for('1234567890')
  end
  
  def test_live_redirect_url_without_review
    Base.gateway_mode = :production
    assert_equal LIVE_REDIRECT_URL_WITHOUT_REVIEW, @gateway.redirect_url_for('1234567890', :review => false)
  end
  
  def test_test_redirect_url_without_review
    assert_equal :test, Base.gateway_mode
    assert_equal TEST_REDIRECT_URL_WITHOUT_REVIEW, @gateway.redirect_url_for('1234567890', :review => false)
  end
  
  def test_invalid_get_express_details_request
    @gateway.expects(:ssl_post).returns(invalid_get_express_details_response)
    response = @gateway.details_for('EC-2OPN7UJGFWK9OYFV')
    assert_failure response
    assert response.test?
    assert_equal 'Field format error: Invalid Token', response.message
  end
  
  def test_get_express_details
    @gateway.expects(:ssl_post).returns(successful_get_express_details_response)
    response = @gateway.details_for('EC-2OPN7UJGFWK9OYFV')
    assert_instance_of PayflowExpressResponse, response
    assert_success response
    assert response.test?
    
    assert_equal 'EC-2OPN7UJGFWK9OYFV', response.token
    assert_equal '12345678901234567', response.payer_id
    assert_equal 'Buyer1@paypal.com', response.email
    assert_equal 'Joe Smith', response.full_name
    assert_equal 'US', response.payer_country
    
    assert address = response.address
    assert_equal 'Joe Smith', address['name']
    assert_nil address['company']
    assert_equal '111 Main St.', address['address1']
    assert_nil address['address2']
    assert_equal 'San Jose', address['city']
    assert_equal 'CA', address['state']
    assert_equal '95100', address['zip']
    assert_equal 'US', address['country']
    assert_nil address['phone']
  end
  
  def test_button_source
    xml = Builder::XmlMarkup.new
    @gateway.send(:add_paypal_details, xml, {})
    xml_doc = REXML::Document.new(xml.target!)
    assert_equal 'ActiveMerchant', REXML::XPath.first(xml_doc, '/PayPal/ButtonSource').text
  end
  
  private
  
  def successful_get_express_details_response
    <<-RESPONSE
<XMLPayResponse xmlns='http://www.verisign.com/XMLPay'>
  <ResponseData>
    <Vendor>TEST</Vendor>
    <Partner>verisign</Partner>
    <TransactionResults>
      <TransactionResult>
        <Result>0</Result>
        <Message>Approved</Message>
        <PayPalResult>
          <EMail>Buyer1@paypal.com</EMail>
          <PayerID>12345678901234567</PayerID>
          <Token>EC-2OPN7UJGFWK9OYFV</Token>
          <FeeAmount>0</FeeAmount>
          <PayerStatus>verified</PayerStatus>
          <Name>Joe</Name>
          <ShipTo>
            <Address>
              <Street>111 Main St.</Street>
              <City>San Jose</City>
              <State>CA</State>
              <Zip>95100</Zip>
              <Country>US</Country>
            </Address>
          </ShipTo>
          <CorrelationID>9c3706997455e</CorrelationID>
        </PayPalResult>
        <ExtData Name='LASTNAME' Value='Smith'/>
      </TransactionResult>
    </TransactionResults>
  </ResponseData>
  </XMLPayResponse>
    RESPONSE
  end
  
  def invalid_get_express_details_response
    <<-RESPONSE
<XMLPayResponse xmlns='http://www.verisign.com/XMLPay'>
  <ResponseData>
    <Vendor>TEST</Vendor>
    <Partner>verisign</Partner>
    <TransactionResults>
      <TransactionResult>
        <Result>7</Result>
        <Message>Field format error: Invalid Token</Message>
      </TransactionResult>
    </TransactionResults>
  </ResponseData>
</XMLPayResponse>    
    RESPONSE
  end
end
