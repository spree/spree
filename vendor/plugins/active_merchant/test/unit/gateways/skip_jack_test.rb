require 'test_helper'

class SkipJackTest < Test::Unit::TestCase

  def setup
    Base.gateway_mode = :test

    @gateway = SkipJackGateway.new(:login => 'X', :password => 'Y')

    @credit_card = credit_card('4242424242424242')

    @billing_address = { 
      :address1 => '123 Any St.',
      :address2 => 'Apt. B',
      :city => 'Anytown',
      :state => 'ST',
      :country => 'US',
      :zip => '51511-1234',
      :phone => '616-555-1212',
      :fax => '616-555-2121'
    }

    @shipping_address = { 
      :name => 'Stew Packman',
      :address1 => 'Company',
      :address2 => '321 No RD',
      :city => 'Nowhereton',
      :state => 'ZC',
      :country => 'MX',
      :phone => '0123231212'
    }
    
    @options = {
      :order_id => 1,
      :email => 'cody@example.com'
    }
    
    @amount = 100
  end

  def test_authorization_success    
    @gateway.expects(:ssl_post).returns(successful_authorization_response)

    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response
    assert_equal '9802853155172.022', response.authorization
  end

  def test_authorization_failure
    @gateway.expects(:ssl_post).returns(unsuccessful_authorization_response)

    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_failure response
  end
  
  def test_purchase_success
    @gateway.expects(:ssl_post).times(2).returns(successful_authorization_response, successful_capture_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal "9802853155172.022", response.authorization
  end
  
  def test_purchase_failure
    @gateway.expects(:ssl_post).returns(unsuccessful_authorization_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_failure response
  end

  def test_split_line
    keys = @gateway.send(:split_line, '"AUTHCODE","szSerialNumber","szTransactionAmount","szAuthorizationDeclinedMessage","szAVSResponseCode","szAVSResponseMessage","szOrderNumber","szAuthorizationResponseCode","szIsApproved","szCVV2ResponseCode","szCVV2ResponseMessage","szReturnCode","szTransactionFileName","szCAVVResponseCode"')
  
    values = @gateway.send(:split_line, '"000067","999888777666","1900","","N","Card authorized, exact address match with 5 digit zipcode.","1","000067","1","","","1","10138083786558.009",""')
  
    assert_equal keys.size, values.size
  
    keyvals = keys.zip(values).flatten
    map = Hash[*keyvals]
  
    assert_equal '000067', map['AUTHCODE']
  end
  
  def test_turn_authorizeapi_response_into_hash
    body = <<-EOS
"AUTHCODE","szSerialNumber","szTransactionAmount","szAuthorizationDeclinedMessage","szAVSResponseCode","szAVSResponseMessage","szOrderNumber","szAuthorizationResponseCode","szIsApproved","szCVV2ResponseCode","szCVV2ResponseMessage","szReturnCode","szTransactionFileName","szCAVVResponseCode"
"000067","999888777666","1900","","N","Card authorized, exact address match with 5 digit zipcode.","1","000067","1","","","1","10138083786558.009",""
    EOS
  
    map = @gateway.send(:authorize_response_map, body)
  
    assert_equal 14, map.keys.size
    assert_equal '10138083786558.009', map[:szTransactionFileName]
  end
  
  def test_avs_result
    @gateway.expects(:ssl_post).returns(successful_authorization_response)
    
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_equal 'Y', response.avs_result['code']
  end
  
  def test_cvv_result
    @gateway.expects(:ssl_post).returns(successful_authorization_response)
    
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_equal 'M', response.cvv_result['code']
  end
  
  private
  def successful_authorization_response
    <<-CSV
"AUTHCODE","szSerialNumber","szTransactionAmount","szAuthorizationDeclinedMessage","szAVSResponseCode","szAVSResponseMessage","szOrderNumber","szAuthorizationResponseCode","szIsApproved","szCVV2ResponseCode","szCVV2ResponseMessage","szReturnCode","szTransactionFileName","szCAVVResponseCode"
"TAS204","000386891209","100","","Y","Card authorized, exact address match with 5 digit zip code.","107a0fdb21ba42cf04f60274908085ea","TAS204","1","M","Match","1","9802853155172.022",""
    CSV
  end
  
  def successful_capture_response
    <<-CSV
"000386891209","0","1","","","","","","","","","" 
"000386891209","1.0000","SETTLE","SUCCESSFUL","Valid","618844630c5fad658e95abfd5e1d4e22","9802853156029.022"
    CSV
  end
  
  def unsuccessful_authorization_response
    <<-CSV
"AUTHCODE","szSerialNumber","szTransactionAmount","szAuthorizationDeclinedMessage","szAVSResponseCode","szAVSResponseMessage","szOrderNumber","szAuthorizationResponseCode","szIsApproved","szCVV2ResponseCode","szCVV2ResponseMessage","szReturnCode","szTransactionFileName","szCAVVResponseCode"\r\n"EMPTY","000386891209","100","","","","b1eec256d0182f29375e0cbae685092d","","0","","","-35","",""
    CSV
  end
end
