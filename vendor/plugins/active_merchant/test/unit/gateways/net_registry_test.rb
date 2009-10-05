require 'test_helper'

class NetRegistryTest < Test::Unit::TestCase
  def setup
    @gateway = NetRegistryGateway.new(
      :login => 'X',
      :password => 'Y'
    )

    @amount = 100
    @credit_card = credit_card
    @options = {
      :order_id => '1',
      :billing_address => address
    }
  end
  
  def test_filtered_fields
    @gateway.stubs(:ssl_post).returns(successful_purchase_response)
    response = @gateway.purchase(@amount, @credit_card, @options)
    
    NetRegistryGateway::FILTERED_PARAMS.each do |param|
      assert_false response.params.has_key?(param)
    end
  end
  
  def test_successful_purchase
    @gateway.stubs(:ssl_post).returns(successful_purchase_response)
    
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_match '0707161858000000', response.authorization
  end

  def test_successful_credit
    @gateway.stubs(:ssl_post).returns(successful_credit_response)
    response = @gateway.credit(@amount, '0707161858000000', @options)
    assert_success response
  end
  
  def test_capture_without_credit_card_provided
    assert_raise(ArgumentError) do
      response = @gateway.capture(@amount, '0707161858000000', @options)
    end
  end

  def test_successful_authorization
    @gateway.stubs(:ssl_post).returns(successful_authorization_response)
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_match /\A\d{6}\z/, response.authorization
    assert_equal '000000', response.authorization
  end

  def test_successful_authorization_and_capture
    @gateway.stubs(:ssl_post).returns(successful_authorization_response, successful_capture_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_match /\A\d{6}\z/, response.authorization

    response = @gateway.capture(@amount, response.authorization, :credit_card => @credit_card)
    assert_success response
  end

  def test_purchase_with_invalid_credit_card
    @gateway.stubs(:ssl_post).returns(purchase_with_invalid_credit_card_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'INVALID CARD', response.message
  end

  def test_purchase_with_expired_credit_card
    @gateway.stubs(:ssl_post).returns(purchase_with_expired_credit_card_response)
    
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'CARD EXPIRED', response.message
  end

  def test_purchase_with_invalid_month
    @gateway.stubs(:ssl_post).returns(purchase_with_invalid_month_response)
    
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Invalid month', response.message
  end

  def test_bad_login
    gateway = NetRegistryGateway.new(:login => 'bad-login', :password => 'bad-login')
    gateway.stubs(:ssl_post).returns(bad_login_response)
    
    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'failed', response.params['status']
  end

  private
  def successful_purchase_response
    <<-RESPONSE
approved
00015X000000
Transaction No: 00000000
------------------------
MERCHANTNAME            
LOCATION          AU
                        
MERCH ID        10000000
TERM  ID          Y0TR00
COUNTRY CODE AU
16/07/07           18:59
RRN         00015X000000
VISA
411111-111
CREDIT A/C         12/10
                        
AUTHORISATION NO: 000000
APPROVED   08
                        
PURCHASE           $1.00
TOTAL   AUD        $1.00
                        
PLEASE RETAIN AS RECORD 
      OF PURCHASE       
                        
(SUBJECT TO CARDHOLDER'S
       ACCEPTANCE)      
------------------------
.
settlement_date=16/07/07
card_desc=VISA
status=approved
txn_ref=0707161858000000
refund_mode=0
transaction_no=000000
rrn=00015X000000
response_text=SIGNATURE REQUIRED
pld=0
total_amount=100
card_no=4111111111111111
version=V1.0
merchant_index=123
card_expiry=12/10
training_mode=0
operator_no=10000
response_code=08
card_type=6
approved=1
cashout_amount=0
receipt_array=ARRAY(0x83725cc)
account_type=CREDIT A/C
result=1
    RESPONSE
  end
  
  def successful_credit_response
    <<-RESPONSE
approved
00015X000000
Transaction No: 00000000
------------------------
MERCHANTNAME        
LOCATION          AU
                        
MERCH ID        10000000
TERM  ID          Y0TR00
COUNTRY CODE AU
16/07/07           19:03
RRN         00015X000000
VISA
411111-111
CREDIT A/C         12/10
                        
AUTHORISATION NO:
APPROVED   08
                        
** REFUND **       $1.00
TOTAL   AUD        $1.00
                        
PLEASE RETAIN AS RECORD 
      OF REFUND         
                        
(SUBJECT TO CARDHOLDER'S
       ACCEPTANCE)      
------------------------
.
settlement_date=16/07/07
card_desc=VISA
status=approved
txn_ref=0707161902000000
refund_mode=1
transaction_no=000000
rrn=00015X000000
response_text=SIGNATURE REQUIRED
pld=0
total_amount=100
card_no=4111111111111111
version=V1.0
merchant_index=123
card_expiry=12/10
training_mode=0
operator_no=10000
response_code=08
card_type=6
approved=1
cashout_amount=0
receipt_array=ARRAY(0x837241c)
account_type=CREDIT A/C
result=1
    RESPONSE
  end
  
  def successful_authorization_response
    <<-RESPONSE
approved
00015X000000
Transaction No: 00000000
------------------------
MERCHANTNAME        
LOCATION          AU
                        
MERCH ID        10000000
TERM  ID          Y0TR00
COUNTRY CODE AU
17/07/07           15:22
RRN         00015X000000
VISA
411111-111
CREDIT A/C         12/10
                        
AUTHORISATION NO: 000000
APPROVED   08
                        
PURCHASE           $1.00
TOTAL   AUD        $1.00
                        
PLEASE RETAIN AS RECORD 
      OF PURCHASE       
                        
(SUBJECT TO CARDHOLDER'S
       ACCEPTANCE)      
------------------------
.
settlement_date=17/07/07
card_desc=VISA
status=approved
txn_ref=0707171521000000
refund_mode=0
transaction_no=000000
rrn=00015X000000
response_text=SIGNATURE REQUIRED
pld=0
total_amount=100
card_no=4111111111111111
version=V1.0
merchant_index=123
card_expiry=12/10
training_mode=0
operator_no=10000
response_code=08
card_type=6
approved=1
cashout_amount=0
receipt_array=ARRAY(0x836a25c)
account_type=CREDIT A/C
result=1    
    RESPONSE
  end
  
  def successful_capture_response
    <<-RESPONSE
approved
00015X000000
Transaction No: 00000000
------------------------
MERCHANTNAME        
LOCATION          AU
                        
MERCH ID        10000000
TERM  ID          Y0TR00
COUNTRY CODE AU
17/07/07           15:23
RRN         00015X000000
VISA
411111-111
CREDIT A/C         12/10
                        
AUTHORISATION NO: 000000
APPROVED   08
                        
PURCHASE           $1.00
TOTAL   AUD        $1.00
                        
PLEASE RETAIN AS RECORD 
      OF PURCHASE       
                        
(SUBJECT TO CARDHOLDER'S
       ACCEPTANCE)      
------------------------
.
settlement_date=17/07/07
card_desc=VISA
status=approved
txn_ref=0707171522000000
refund_mode=0
transaction_no=000000
rrn=00015X000000
response_text=SIGNATURE REQUIRED
pld=0
total_amount=100
card_no=4111111111111111
version=V1.0
merchant_index=123
card_expiry=12/10
training_mode=0
operator_no=10000
response_code=08
card_type=6
approved=1
cashout_amount=0
receipt_array=ARRAY(0x8378200)
account_type=CREDIT A/C
result=1    
    RESPONSE
  end
  
  def purchase_with_invalid_credit_card_response
    <<-RESPONSE
declined
00015X000000
Transaction No: 00000000
------------------------
MERCHANTNAME        
LOCATION          AU
                        
MERCH ID        10000000
TERM  ID          Y0TR40
COUNTRY CODE AU
16/07/07           19:20
RRN         00015X000000
VISA
411111-111
CREDIT A/C         12/10
                        
AUTHORISATION NO:
DECLINED   31
                        
PURCHASE           $1.00
TOTAL   AUD        $1.00
                        
(SUBJECT TO CARDHOLDER'S
       ACCEPTANCE)      
------------------------
.
settlement_date=16/07/07
card_desc=VISA
status=declined
txn_ref=0707161919000000
refund_mode=0
transaction_no=000000
rrn=00015X000000
response_text=INVALID CARD
pld=0
total_amount=100
card_no=4111111111111111
version=V1.0
merchant_index=123
card_expiry=12/10
training_mode=0
operator_no=10000
response_code=31
card_type=6
approved=0
cashout_amount=0
receipt_array=ARRAY(0x83752d0)
account_type=CREDIT A/C
result=0    
RESPONSE
  end
  
  def purchase_with_expired_credit_card_response
    <<-RESPONSE
failed


.
response_text=CARD EXPIRED
approved=0
status=failed
txn_ref=0707161910000000
version=V1.0
pld=0
response_code=Q816
result=-1
    RESPONSE
  end
  
  def purchase_with_invalid_month_response
    <<-RESPONSE
failed
Invalid month
    RESPONSE
  end
  
  def bad_login_response
    <<-RESPONSE
failed


.
status=failed
result=-1
    RESPONSE
  end
end
