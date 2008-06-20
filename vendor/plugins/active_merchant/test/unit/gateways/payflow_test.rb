require File.dirname(__FILE__) + '/../../test_helper'

class PayflowTest < Test::Unit::TestCase
  def setup
    Base.mode = :test
    
    @gateway = PayflowGateway.new(
      :login => 'LOGIN',
      :password => 'PASSWORD'
    )
    
    @amount = 100
    @credit_card = credit_card('4242424242424242')
    @options = { :billing_address => address }
  end
  
  def test_successful_authorization
    @gateway.stubs(:ssl_post).returns(successful_authorization_response)
    
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_equal "Approved", response.message
    assert_success response
    assert response.test?
    assert_equal "VUJN1A6E11D9", response.authorization
  end
  
  def test_failed_authorization
    @gateway.stubs(:ssl_post).returns(failed_authorization_response)
    
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_equal "Declined", response.message
    assert_failure response
    assert response.test?
  end
  
  def test_avs_result
    @gateway.expects(:ssl_post).returns(successful_authorization_response)
    
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'Y', response.avs_result['code']
    assert_equal 'Y', response.avs_result['street_match']
    assert_equal 'Y', response.avs_result['postal_match']
  end
  
  def test_partial_avs_match
    @gateway.expects(:ssl_post).returns(successful_duplicate_response)
    
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'A', response.avs_result['code']
    assert_equal 'Y', response.avs_result['street_match']
    assert_equal 'N', response.avs_result['postal_match']
  end
  
  def test_cvv_result
    @gateway.expects(:ssl_post).returns(successful_authorization_response)
    
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'M', response.cvv_result['code']
  end
  
  def test_using_test_mode
    assert @gateway.test?
  end
  
  def test_overriding_test_mode
    Base.gateway_mode = :production
    
    gateway = PayflowGateway.new(
      :login => 'LOGIN',
      :password => 'PASSWORD',
      :test => true
    )
    
    assert gateway.test?
  end
  
  def test_using_production_mode
    Base.gateway_mode = :production
    
    gateway = PayflowGateway.new(
      :login => 'LOGIN',
      :password => 'PASSWORD'
    )
    
    assert !gateway.test?
  end
  
  def test_partner_class_accessor
    assert_equal 'PayPal', PayflowGateway.partner
    gateway = PayflowGateway.new(:login => 'test', :password => 'test')
    assert_equal 'PayPal', gateway.options[:partner]
  end
  
  def test_passed_in_partner_overrides_class_accessor
    assert_equal 'PayPal', PayflowGateway.partner
    gateway = PayflowGateway.new(:login => 'test', :password => 'test', :partner => 'PayPalUk')
    assert_equal 'PayPalUk', gateway.options[:partner]
  end
  
  def test_express_instance
    PayflowGateway.certification_id = '123456'
    gateway = PayflowGateway.new(
      :login => 'test',
      :password => 'password'
    )
    express = gateway.express
    assert_instance_of PayflowExpressGateway, express
    assert_equal '123456', express.options[:certification_id]
    assert_equal 'PayPal', express.options[:partner]
    assert_equal 'test', express.options[:login]
    assert_equal 'password', express.options[:password]
  end

  def test_default_currency
    assert_equal 'USD', PayflowGateway.default_currency
  end
  
  def test_supported_countries
    assert_equal ['US', 'CA', 'SG', 'AU'], PayflowGateway.supported_countries
  end
  
  def test_supported_card_types
    assert_equal [:visa, :master, :american_express, :jcb, :discover, :diners_club], PayflowGateway.supported_cardtypes
  end
  
  def test_initial_recurring_transaction_missing_parameters
    assert_raises ArgumentError do
      response = @gateway.recurring(@amount, @credit_card, 
        :periodicity => :monthly,
        :initial_transaction => { }
      )
    end
  end
  
  def test_initial_purchase_missing_amount
    assert_raises ArgumentError do
      response = @gateway.recurring(@amount, @credit_card, 
        :periodicity => :monthly,
        :initial_transaction => { :amount => :purchase }
      )
    end
  end
  
  def test_successful_recurring_action
    @gateway.stubs(:ssl_post).returns(successful_recurring_response)
    
    response = @gateway.recurring(@amount, @credit_card, :periodicity => :monthly)
    
    assert_instance_of PayflowResponse, response
    assert_success response
    assert_equal 'RT0000000009', response.profile_id
    assert response.test?
    assert_equal "R7960E739F80", response.authorization
  end
  
  def test_recurring_profile_payment_history_inquiry
    @gateway.stubs(:ssl_post).returns(successful_payment_history_recurring_response)
    
    response = @gateway.recurring_inquiry('RT0000000009', :history => true)
    assert_equal 1, response.payment_history.size
    assert_equal '1', response.payment_history.first['payment_num']
    assert_equal '7.25', response.payment_history.first['amt']
  end
  
  def test_recurring_profile_payment_history_inquiry_contains_the_proper_xml
    request = @gateway.send( :build_recurring_request, :inquiry, nil, :profile_id => 'RT0000000009', :history => true)
    assert_match %r(<PaymentHistory>Y</PaymentHistory), request
  end
  
  def test_format_issue_number
    xml = Builder::XmlMarkup.new
    credit_card = credit_card("5641820000000005",
      :type         => "switch",
      :issue_number => 1
    )
    
    @gateway.send(:add_credit_card, xml, credit_card)
    doc = REXML::Document.new(xml.target!)
    node = REXML::XPath.first(doc, '/Card/ExtData')
    assert_equal '01', node.attributes['Value']
  end
  
  def test_duplicate_response_flag
    @gateway.expects(:ssl_post).returns(successful_duplicate_response)
    
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert response.params['duplicate']
  end
  
  def test_ensure_gateway_uses_safe_retry
    assert @gateway.retry_safe
  end
    
  private
  def successful_recurring_response
    <<-XML
<ResponseData>
  <Result>0</Result>
  <Message>Approved</Message>
  <Partner>paypal</Partner>
  <RPRef>R7960E739F80</RPRef>
  <Vendor>ActiveMerchant</Vendor>
  <ProfileId>RT0000000009</ProfileId>
</ResponseData>
  XML
  end
  
  def successful_payment_history_recurring_response
    <<-XML
<ResponseData>
  <Result>0</Result>
  <Partner>paypal</Partner>
  <RPRef>R7960E739F80</RPRef>
  <Vendor>ActiveMerchant</Vendor>
  <ProfileId>RT0000000009</ProfileId>
  <RPPaymentResult>
    <PaymentNum>1</PaymentNum>
    <PNRef>V18A0D3048AF</PNRef>
    <TransTime>12-Jan-08 04:30 AM</TransTime>
    <Result>0</Result>
    <Tender>C</Tender>
    <Amt Currency="7.25"></Amt>
    <TransState>6</TransState>
  </RPPaymentResult>
</ResponseData>
  XML
  end
  
  def successful_authorization_response
    <<-XML
<ResponseData>
    <Result>0</Result>
    <Message>Approved</Message>
    <Partner>verisign</Partner>
    <HostCode>000</HostCode>
    <ResponseText>AP</ResponseText>
    <PnRef>VUJN1A6E11D9</PnRef>
    <IavsResult>N</IavsResult>
    <ZipMatch>Match</ZipMatch>
    <AuthCode>094016</AuthCode>
    <Vendor>ActiveMerchant</Vendor>
    <AvsResult>Y</AvsResult>
    <StreetMatch>Match</StreetMatch>
    <CvResult>Match</CvResult>
</ResponseData>
    XML
  end
  
  def failed_authorization_response
    <<-XML
<ResponseData>
    <Result>12</Result>
    <Message>Declined</Message>
    <Partner>verisign</Partner>
    <HostCode>000</HostCode>
    <ResponseText>AP</ResponseText>
    <PnRef>VUJN1A6E11D9</PnRef>
    <IavsResult>N</IavsResult>
    <ZipMatch>Match</ZipMatch>
    <AuthCode>094016</AuthCode>
    <Vendor>ActiveMerchant</Vendor>
    <AvsResult>Y</AvsResult>
    <StreetMatch>Match</StreetMatch>
    <CvResult>Match</CvResult>
</ResponseData>
    XML
  end
  
  def successful_duplicate_response
    <<-XML
<?xml version="1.0"?>
<XMLPayResponse xmlns="http://www.verisign.com/XMLPay">
	<ResponseData>
		<Vendor>ActiveMerchant</Vendor>
		<Partner>paypal</Partner>
		<TransactionResults>
			<TransactionResult Duplicate="true">
				<Result>0</Result>
				<ProcessorResult>
					<AVSResult>A</AVSResult>
					<CVResult>M</CVResult>
					<HostCode>A</HostCode>
				</ProcessorResult>
				<IAVSResult>N</IAVSResult>
				<AVSResult>
					<StreetMatch>Match</StreetMatch>
					<ZipMatch>No Match</ZipMatch>
				</AVSResult>
				<CVResult>Match</CVResult>
				<Message>Approved</Message>
				<PNRef>V18A0CBB04CF</PNRef>
				<AuthCode>692PNI</AuthCode>
				<ExtData Name="DATE_TO_SETTLE" Value="2007-11-28 10:53:50"/>
			</TransactionResult>
		</TransactionResults>
	</ResponseData>
</XMLPayResponse>
    XML
  end
end
