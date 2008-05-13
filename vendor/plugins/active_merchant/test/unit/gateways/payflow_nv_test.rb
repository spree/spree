require File.dirname(__FILE__) + '/../../test_helper'

class PayflowNvTest < Test::Unit::TestCase
  def setup
    Base.mode = :test

    @gateway = PayflowNvGateway.new(
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
    assert_equal 'Y', response.avs_result['postal_match']
    assert_equal 'Y', response.avs_result['street_match']
    assert_equal 'Y', response.avs_result['code']
  end

  def test_partial_avs_match
    @gateway.expects(:ssl_post).returns(successful_duplicate_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'Y', response.avs_result['street_match']
    assert_equal 'N', response.avs_result['postal_match']
    assert_equal 'A', response.avs_result['code']
  end

  def test_cvv_result
    @gateway.expects(:ssl_post).returns(successful_authorization_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'Y', response.cvv_result['code']
  end

  def test_using_test_mode
    assert @gateway.test?
  end

  def test_overriding_test_mode
    Base.gateway_mode = :production

    gateway = PayflowNvGateway.new(
      :login => 'LOGIN',
      :password => 'PASSWORD',
      :test => true
    )

    assert gateway.test?
  end

  def test_using_production_mode
    Base.gateway_mode = :production

    gateway = PayflowNvGateway.new(
      :login => 'LOGIN',
      :password => 'PASSWORD'
    )

    assert !gateway.test?
  end

  def test_partner_class_accessor
    assert_equal 'PayPal', PayflowNvGateway.partner
    gateway = PayflowNvGateway.new(:login => 'test', :password => 'test')
    assert_equal 'PayPal', gateway.options[:partner]
  end

  def test_passed_in_partner_overrides_class_accessor
    assert_equal 'PayPal', PayflowNvGateway.partner
    gateway = PayflowNvGateway.new(:login => 'test', :password => 'test', :partner => 'PayPalUk')
    assert_equal 'PayPalUk', gateway.options[:partner]
  end

  def test_express_instance
    PayflowNvGateway.certification_id = '123456'
    gateway = PayflowNvGateway.new(
      :login => 'test',
      :password => 'password'
    )
    express = gateway.express
    assert_instance_of PayflowExpressNvGateway, express
    assert_equal '123456', express.options[:certification_id]
    assert_equal 'PayPal', express.options[:partner]
    assert_equal 'test', express.options[:login]
    assert_equal 'password', express.options[:password]
  end

  def test_default_currency
    assert_equal 'USD', PayflowNvGateway.default_currency
  end

  def test_supported_countries
    assert_equal ['US', 'CA', 'SG', 'AU'], PayflowNvGateway.supported_countries
  end

  def test_supported_card_types
    assert_equal [:visa, :master, :american_express, :jcb, :discover, :diners_club], PayflowNvGateway.supported_cardtypes
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
    @gateway.stubs(:ssl_post).returns(successful_recurring_add_response)

    response = @gateway.recurring(@amount, @credit_card, :periodicity => :monthly)

    assert_instance_of PayflowNvResponse, response
    assert_success response
    assert response.test?
    assert_equal "RWY504915344", response.authorization
    assert_equal 'RP000000001234', response.profile_id
  end

  def test_recurring_profile_payment_history_inquiry
    @gateway.stubs(:ssl_post).returns(successful_payment_history_recurring_response)

    response = @gateway.recurring_inquiry('RT0000000009', :history => true)
    assert_equal 6, response.payment_history.size
    assert_equal '1', response.payment_history.first['payment_num']
    assert_equal '1.00', response.payment_history.first['amt']
  end

  def test_recurring_profile_payment_history_inquiry_contains_the_proper_xml
    request = @gateway.send( :build_recurring_request, :inquiry, nil, :profile_id => 'RT0000000009', :history => true)
    assert_equal "Y", request[:paymenthistory]
  end

  #def test_format_issue_number
  #  xml = Builder::XmlMarkup.new
  #  credit_card = credit_card("5641820000000005",
  #    :type         => "switch",
  #    :issue_number => 1
  #  )
  #
  #  @gateway.send(:add_credit_card, xml, credit_card)
  #  doc = REXML::Document.new(xml.target!)
  #  node = REXML::XPath.first(doc, '/Card/ExtData')
  #  assert_equal '01', node.attributes['Value']
  #end

  def test_duplicate_response_flag
    @gateway.expects(:ssl_post).returns(successful_duplicate_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert response.params['duplicate']
  end

  def test_ensure_gateway_uses_safe_retry
    assert @gateway.retry_safe
  end
  
  def test_response_under_review_by_fraud_service
    @gateway.expects(:ssl_post).returns(fraud_review_response)
    
    response = @gateway.purchase(@amount, @credit_card)
    assert_failure response
    assert response.fraud_review?
    assert_equal "", response.message
  end

  private

  def successful_recurring_add_response
    "RESULT=0&RPREF=RWY504915344&PROFILEID=RP000000001234&RESPMSG=Approved&TRXRESULT=0&TRXPNREF=VWYA04915345&TRXRESPMSG=Approved&AUTHCODE=489PNI"
  end

  def successful_payment_history_recurring_response
    res = "RESULT=0&RPREF=RKM500141021&PROFILEID=RT0000000100&"
    res << "P_PNREF1=VWYA06156256&P_TRANSTIME1=21-May-04 04:47PM&P_RESULT1=0&P_TENDER1=C&P_AMT1=1.00&P_TRANSTATE1=8&"
    res << "P_PNREF2=VWYA06156269&P_TRANSTIME2=27-May-04 01:19PM&P_RESULT2=0&P_TENDER2=C&P_AMT2=1.00&P_TRANSTATE2=8&"
    res << "P_PNREF3=VWYA06157650&P_TRANSTIME3=03-Jun-04 04:47PM&P_RESULT3=0&P_TENDER3=C&P_AMT3=1.00&P_TRANSTATE3=8&"
    res << "P_PNREF4=VWYA06157668&P_TRANSTIME4=10-Jun-04 04:47PM&P_RESULT4=0&P_TENDER4=C&P_AMT4=1.00&P_TRANSTATE4=8&"
    res << "P_PNREF5=VWYA06158795&P_TRANSTIME5=17-Jun-04 04:47PM&P_RESULT5=0&P_TENDER5=C&P_AMT5=1.00&P_TRANSTATE5=8&"
    res << "P_PNREF6=VJLA00000060&P_TRANSTIME6=05-Aug-04 05:54PM&P_RESULT6=0&P_TENDER6=C&P_AMT6=1.00&P_TRANSTATE6=1"
    res
  end

  def successful_authorization_response
    "RESULT=0&PNREF=VUJN1A6E11D9&RESPMSG=Approved&AUTHCODE=123456&AVSADDR=Y&AVSZIP=Y&CVV2MATCH=Y&IAVS=Y&PROCAVS=Y"
  end

  def failed_authorization_response
    "RESULT=12&PNREF=VXYZ01234567&RESPMSG=Declined&BALANCE=99.00&AVSADDR=Y&AVSZIP=N"
  end

  def successful_duplicate_response
    "RESULT=0&PNREF=VUJN1A6E11D9&RESPMSG=Approved&AUTHCODE=123456&AVSADDR=Y&AVSZIP=N&CVV2MATCH=Y&HOSTCODE=A&PROCAVS=A&PROCCVV2=M&DATE_TO_SETTLE=2008-02-27 17:40:30&IAVS=N&DUPLICATE=1"
  end
  
  def fraud_review_response
    'RESULT=126&PNREF=V79A0D0CA828&RESPMSG=Under review by Fraud Service&AUTHCODE=505PNI&AVSADDR=Y&AVSZIP=Y&CVV2MATCH=Y&HOSTCODE=A&PROCAVS=Y&PROCCVV2=M&IAVS=N&PREFPSMSG=Review: More than one rule was triggered for Review&FPS_PREXMLDATA[2830]=<triggeredRules><rule num="1"><ruleId>18</ruleId><ruleID>18</ruleID><ruleAlias>InternationalOrder</ruleAlias><ruleDescription>International Shipping/Billing Address</ruleDescription><action>R</action><triggeredMessage>International billing and shipping addresses</triggeredMessage></rule><rule num="2"><ruleId>46</ruleId><ruleID>46</ruleID><ruleAlias>AccountNumberVelocity</ruleAlias><ruleDescription>Account Number Velocity</ruleDescription><action>R</action><triggeredMessage>The card used in this transaction has been used at least 6 times recently</triggeredMessage><rulevendorparms><ruleParameter num="1"><name>CardVelocityTrigger</name><value type="Integer">6</value></ruleParameter></rulevendorparms><extendedData><extendedDataEntry index="1"><extendedDataItem type="integer"><name>FPSID</name><value>10586727</value></extendedDataItem><extendedDataItem type="string"><name>TRANS_DATE</name><value>3/3/2008 8:20:18</value></extendedDataItem><extendedDataItem type="string"><name>PNREFID</name><value>V70A0D0CA828</value></extendedDataItem></extendedDataEntry><extendedDataEntry index="2"><extendedDataItem type="integer"><name>FPSID</name><value>10586664</value></extendedDataItem><extendedDataItem type="string"><name>TRANS_DATE</name><value>3/3/2008 8:18:16</value></extendedDataItem><extendedDataItem type="string"><name>PNREFID</name><value>V78A0D0CA6B8</value></extendedDataItem></extendedDataEntry><extendedDataEntry index="3"><extendedDataItem type="integer"><name>FPSID</name><value>10586617</value></extendedDataItem><extendedDataItem type="string"><name>TRANS_DATE</name><value>3/3/2008 8:15:30</value></extendedDataItem><extendedDataItem type="string"><name>PNREFID</name><value>V79A0D0CA4FB</value></extendedDataItem></extendedDataEntry><extendedDataEntry index="4"><extendedDataItem type="integer"><name>FPSID</name><value>10586594</value></extendedDataItem><extendedDataItem type="string"><name>TRANS_DATE</name><value>3/3/2008 8:14:45</value></extendedDataItem><extendedDataItem type="string"><name>PNREFID</name><value>V19A0D9FAE53</value></extendedDataItem></extendedDataEntry><extendedDataEntry index="5"><extendedDataItem type="integer"><name>FPSID</name><value>10586552</value></extendedDataItem><extendedDataItem type="string"><name>TRANS_DATE</name><value>3/3/2008 8:12:29</value></extendedDataItem><extendedDataItem type="string"><name>PNREFID</name><value>V18A0D9FAE41</value></extendedDataItem></extendedDataEntry><extendedDataEntry index="6"><extendedDataItem type="integer"><name>FPSID</name><value>10585793</value></extendedDataItem><extendedDataItem type="string"><name>TRANS_DATE</name><value>3/3/2008 7:34:20</value></extendedDataItem><extendedDataItem type="string"><name>PNREFID</name><value>V19A0D9FADAC</value></extendedDataItem></extendedDataEntry></extendedData></rule></triggeredRules>&POSTFPSMSG=Review'
  end

end
