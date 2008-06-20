require 'test/unit'
require File.dirname(__FILE__) + '/../../test_helper'

class PayJunctionTest < Test::Unit::TestCase
  def setup
    Base.gateway_mode = :test

    @gateway = PayJunctionGateway.new(
                 :login      => "pj-ql-01",
                 :password   => "pj-ql-01p"
               )

    @credit_card = credit_card
    @options = {
      :billing_address => address,
      :description => 'Test purchase'
    }
    @amount = 100
  end
 
  
  def test_detect_test_credentials_when_in_production  
    Base.mode = :production
    
    live_gw  = PayJunctionGateway.new(
                 :login      => "l",
                 :password   => "p"
               )
    assert_false live_gw.test?
    
    test_gw = PayJunctionGateway.new(
                :login      => "pj-ql-01",
                :password   => "pj-ql-01p"
              ) 
    assert test_gw.test?
  end
  
  def test_successful_authorization
    @gateway.expects(:ssl_post).returns(successful_authorization_response)
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal PayJunctionGateway::SUCCESS_MESSAGE, response.message
  end
  
  def test_failed_authorization
    @gateway.expects(:ssl_post).returns(failed_authorization_response)
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert_equal PayJunctionGateway::DECLINE_CODES['FE'], response.message
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
  def successful_authorization_response
    <<-RESPONSE
dc_merchant_name=PayJunction - (demo)dc_merchant_address=3 W. Carrillodc_merchant_city=Santa Barbaradc_merchant_state=CAdc_merchant_zip=93101dc_merchant_phone=800-601-0230dc_device_id=1174dc_transaction_date=2007-11-28 19:22:33.791634dc_transaction_action=chargedc_approval_code=TAS193dc_response_code=00dc_response_message=APPROVAL TAS193 dc_transaction_id=3144302dc_posture=holddc_invoice_number=9f76c4e4bd66a36dc5aeb4bd7b3a02fadc_notes=--START QUICK-LINK DEBUG--
----Vars Received----
dc_expiration_month =&gt; *
dc_expiration_year =&gt; *
dc_invoice =&gt; 9f76c4e4bd66a36dc5aeb4bd7b3a02fa
dc_logon =&gt; pj-ql-01
dc_name =&gt; Cody Fauser
dc_number =&gt; *
dc_password =&gt; *
dc_transaction_amount =&gt; 4.00
dc_transaction_type =&gt; AUTHORIZATION
dc_verification_number =&gt; *
dc_version =&gt; 1.2
----End Vars----

----Start Response Sent----
dc_merchant_name=PayJunction - (demo)
dc_merchant_address=3 W. Carrillo
dc_merchant_city=Santa Barbara
dc_merchant_state=CA
dc_merchant_zip=93101
dc_merchant_phone=800-601-0230
dc_device_id=1174
dc_transaction_date=2007-11-28 19:22:33.791634
dc_transaction_action=charge
dc_approval_code=TAS193
dc_response_code=00
dc_response_message=APPROVAL TAS193 
dc_transaction_id=3144302
dc_posture=hold
dc_invoice_number=9f76c4e4bd66a36dc5aeb4bd7b3a02fa
dc_notes=null
dc_card_name=cody fauser
dc_card_brand=VSA
dc_card_exp=XX/XX
dc_card_number=XXXX-XXXX-XXXX-3344
dc_card_address=
dc_card_city=
dc_card_zipcode=
dc_card_state=
dc_card_country=
dc_base_amount=4.00
dc_tax_amount=0.00
dc_capture_amount=4.00
dc_cashback_amount=0.00
dc_shipping_amount=0.00
----End Response Sent----
dc_card_name=cody fauserdc_card_brand=VSAdc_card_exp=XX/XXdc_card_number=XXXX-XXXX-XXXX-3344dc_card_address=dc_card_city=dc_card_zipcode=dc_card_state=dc_card_country=dc_base_amount=4.00dc_tax_amount=0.00dc_capture_amount=4.00dc_cashback_amount=0.00dc_shipping_amount=0.00
    RESPONSE
  end
  
  def failed_authorization_response
    'dc_merchant_name=dc_merchant_address=dc_merchant_city=dc_merchant_state=dc_merchant_zip=dc_merchant_phone=dc_device_id=dc_transaction_date=dc_transaction_action=dc_approval_code=dc_response_code=FEdc_response_message=dc_number [Input is invalid.  The credit card number is bad.], System [error.System], dc_transaction_id=dc_posture=dc_invoice_number=dc_notes=dc_card_name=dc_card_brand=dc_card_exp=dc_card_number=dc_card_address=dc_card_city=dc_card_zipcode=dc_card_state=dc_card_country=dc_base_amount=dc_tax_amount=dc_capture_amount=dc_cashback_amount=dc_shipping_amount='
  end
end
