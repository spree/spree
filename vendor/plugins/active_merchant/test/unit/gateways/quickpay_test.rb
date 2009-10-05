require 'test_helper'

class QuickpayTest < Test::Unit::TestCase
  def setup
    @gateway = QuickpayGateway.new(
      :login => 'LOGIN',
      :password => 'PASSWORD'
    )

    @credit_card = credit_card('4242424242424242')
    @amount = 100
    @options = { :order_id => '1', :billing_address => address }
  end
  
  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_authorization_response, successful_capture_response)
    
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal '2865261', response.authorization
    assert response.test?
  end
  
  def test_successful_authorization
    @gateway.expects(:ssl_post).returns(successful_authorization_response)
    
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal '2865261', response.authorization
    assert response.test?
  end

  def test_failed_authorization
    @gateway.expects(:ssl_post).returns(failed_authorization_response)
    
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Missing/error in card verification data', response.message
    assert response.test?
  end
  
  def test_parsing_response_with_errors
    @gateway.expects(:ssl_post).returns(error_response)
    
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal '008', response.params['qpstat']
    assert_equal 'Missing/error in cardnumber, Missing/error in expirationdate, Missing/error in card verification data, Missing/error in amount, Missing/error in ordernum, Missing/error in currency', response.params['qpstatmsg']
    assert_equal 'Missing/error in cardnumber, Missing/error in expirationdate, Missing/error in card verification data, Missing/error in amount, Missing/error in ordernum, Missing/error in currency', response.message
  end
  
  def test_merchant_error
    @gateway.expects(:ssl_post).returns(merchant_error)
    
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal response.message, 'Missing/error in merchant'
  end
  
  def test_parsing_successful_response
    @gateway.expects(:ssl_post).returns(successful_authorization_response)
    
    response = @gateway.authorize(@amount, @credit_card, @options)

    assert_success response
    assert_equal 'OK', response.message
    
    assert_equal '2865261', response.authorization
    assert_equal '000', response.params['qpstat']
    assert_equal '000', response.params['pbsstat']
    assert_equal '2865261', response.params['transaction']
    assert_equal '070425223705', response.params['time']
    assert_equal '104680', response.params['ordernum']
    assert_equal 'cody@example.com', response.params['merchantemail']
    assert_equal 'Visa', response.params['cardtype']
    assert_equal @amount.to_s, response.params['amount']
    assert_equal 'OK', response.params['qpstatmsg']
    assert_equal 'Shopify', response.params['merchant']
    assert_equal '1110', response.params['msgtype']
    assert_equal 'USD', response.params['currency']
  end
  
  def test_supported_countries
    assert_equal ['DK'], QuickpayGateway.supported_countries
  end
  
  def test_supported_card_types
    assert_equal  [ :dankort, :forbrugsforeningen, :visa, :master, :american_express, :diners_club, :jcb, :maestro ], QuickpayGateway.supported_cardtypes
  end
  
  private
  
  def error_response
    "<?xml version='1.0' encoding='ISO-8859-1'?><response><qpstat>008</qpstat><qpstatmsg>Missing/error in cardnumber, Missing/error in expirationdate, Missing/error in card verification data, Missing/error in amount, Missing/error in ordernum, Missing/error in currency</qpstatmsg></response>"
  end
  
  def merchant_error
    "<?xml version='1.0' encoding='ISO-8859-1'?><response><qpstat>008</qpstat><qpstatmsg>Missing/error in merchant</qpstatmsg></response>"
  end
  
  def successful_authorization_response
    "<?xml version='1.0' encoding='ISO-8859-1'?><response><qpstat>000</qpstat><transaction>2865261</transaction><time>070425223705</time><ordernum>104680</ordernum><merchantemail>cody@example.com</merchantemail><pbsstat>000</pbsstat><cardtype>Visa</cardtype><amount>100</amount><qpstatmsg>OK</qpstatmsg><merchant>Shopify</merchant><msgtype>1110</msgtype><currency>USD</currency></response>"
  end
  
  def successful_capture_response
    '<?xml version="1.0" encoding="ISO-8859-1"?><response><msgtype>1230</msgtype><amount>100</amount><time>080107061755</time><pbsstat>000</pbsstat><qpstat>000</qpstat><qpstatmsg>OK</qpstatmsg><currency>DKK</currency><ordernum>4820346075804536193</ordernum><transaction>2865261</transaction><merchant>Shopify</merchant><merchantemail>pixels@jadedpixel.com</merchantemail></response>'
  end
  
  def failed_authorization_response
    '<?xml version="1.0" encoding="ISO-8859-1"?><response><qpstat>008</qpstat><qpstatmsg>Missing/error in card verification data</qpstatmsg></response>'
  end
end
