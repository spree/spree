require 'test_helper'

class TransFirstTest < Test::Unit::TestCase

  def setup
    @gateway = TransFirstGateway.new(
      :login => 'LOGIN',
      :password => 'PASSWORD'
    )

    @credit_card = credit_card('4242424242424242')
    @options = {
      :billing_address => address
    }
    @amount = 100
  end
  
  def test_missing_field_response
    @gateway.stubs(:ssl_post).returns(missing_field_response)
    
    response = @gateway.purchase(@amount, @credit_card, @options)
    
    assert_failure response
    assert response.test?
    assert_equal 'Missing parameter: UserId.', response.message
  end
  
  def test_successful_purchase
    @gateway.stubs(:ssl_post).returns(successful_purchase_response)
    
    response = @gateway.purchase(@amount, @credit_card, @options)
    
    assert_success response
    assert response.test?
    assert_equal 'test transaction', response.message
    assert_equal '355', response.authorization
  end
  
  def test_failed_purchase
    @gateway.stubs(:ssl_post).returns(failed_purchase_response)
    
    response = @gateway.purchase(@amount, @credit_card, @options)
    
    assert_failure response
    assert response.test?
    assert_equal '29005716', response.authorization
    assert_equal 'Invalid cardholder number', response.message
  end
  
  def test_avs_result
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'X', response.avs_result['code']
  end
  
  def test_cvv_result
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'M', response.cvv_result['code']
  end
  
  private
  def missing_field_response
    "Missing parameter: UserId.\r\n"
  end
  
  def successful_purchase_response
    <<-XML
<?xml version="1.0" encoding="utf-8"?> 
<CCSaleDebitResponse xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://www.paymentresources.com/webservices/"> 
  <TransID>355</TransID> 
  <RefID>c2535abbf0bb38005a14fd575553df65</RefID> 
  <Amount>1.00</Amount> 
  <AuthCode>Test00</AuthCode> 
  <Status>Authorized</Status> 
  <AVSCode>X</AVSCode> 
  <Message>test transaction</Message> 
  <CVV2Code>M</CVV2Code> 
  <ACI /> 
  <AuthSource /> 
  <TransactionIdentifier /> 
  <ValidationCode /> 
  <CAVVResultCode /> 
</CCSaleDebitResponse>
    XML
  end
  
  def failed_purchase_response
    <<-XML
<?xml version="1.0" encoding="utf-8" ?>  
<CCSaleDebitResponse xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://www.paymentresources.com/webservices/"> 
  <TransID>29005716</TransID> 
  <RefID>0610</RefID>  
  <PostedDate>2005-09-29T15:16:23.7297658-07:00</PostedDate>  
  <SettledDate>2005-09-29T15:16:23.9641468-07:00</SettledDate>  
  <Amount>0.02</Amount>  
  <AuthCode />  
  <Status>Declined</Status>  
  <AVSCode />  
  <Message>Invalid cardholder number</Message>  
  <CVV2Code />  
  <ACI />  
  <AuthSource />  
  <TransactionIdentifier />  
  <ValidationCode />  
  <CAVVResultCode />  
</CCSaleDebitResponse>
    XML
  end
end
