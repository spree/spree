require 'test_helper'

class PlugnpayTest < Test::Unit::TestCase

  def setup
    Base.gateway_mode = :test
    
    @gateway = PlugnpayGateway.new(
      :login => 'X',
      :password => 'Y'
    )
      
    @credit_card = credit_card
    @options = {
      :billing_address => address,
      :description => 'Store purchase'
    }
    @amount = 100
  end

  def test_purchase_success
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal Response, response.class
    assert_success response
    assert_equal '2008012522252119738', response.authorization
  end

  def test_purchase_error
    @gateway.expects(:ssl_post).returns(unsuccessful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal Response, response.class
    assert_failure response
  end
  
  def test_add_address_outsite_north_america
    result = PlugnpayGateway::PlugnpayPostData.new
    
    @gateway.send(:add_addresses, result, :billing_address => {:address1 => '164 Waverley Street', :country => 'DE', :state => 'Dortmund'} )
    
    assert_equal result[:state], 'ZZ'
    assert_equal result[:province], 'Dortmund'
    
    assert_equal result[:card_state], 'ZZ'
    assert_equal result[:card_prov], 'Dortmund'
    
    assert_equal result[:card_address1], '164 Waverley Street'
    assert_equal result[:card_country], 'DE'
    
  end
                                                             
  def test_add_address
    result = PlugnpayGateway::PlugnpayPostData.new
    
    @gateway.send(:add_addresses, result, :billing_address => {:address1 => '164 Waverley Street', :country => 'US', :state => 'CO'} )
    
    assert_equal result[:card_state], 'CO'
    assert_equal result[:card_address1], '164 Waverley Street'
    assert_equal result[:card_country], 'US'
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
  def successful_purchase_response
    "FinalStatus=success&IPaddress=72%2e138%2e32%2e216&MStatus=success&User_Agent=&acct_code3=newcard&address1=1234%20My%20Street&address2=Apt%201&app_level=5&auth_code=TSTAUT&auth_date=20080125&auth_msg=%20&authtype=authpostauth&avs_code=X&card_address1=1234%20My%20Street&card_amount=1%2e00&card_city=Ottawa&card_country=CA&card_name=Longbob%20Longsen&card_state=ON&card_type=VISA&card_zip=K1C2N6&city=Ottawa&convert=underscores&country=CA&currency=usd&cvvresp=M&dontsndmail=yes&easycart=0&merchant=pnpdemo2&merchfraudlev=&mode=auth&orderID=2008012522252119738&phone=555%2d555%2d5555&publisher_email=trash%40plugnpay%2ecom&publisher_name=pnpdemo2&publisher_password=pnpdemo222&resp_code=00&shipinfo=0&shipname=Jim%20Smith&sresp=A&state=ON&success=yes&zip=K1C2N6&a=b\n"
  end
  
  def unsuccessful_purchase_response
    "FinalStatus=fraud&IPaddress=72%2e138%2e32%2e216&MStatus=badcard&User_Agent=&address1=1234%20My%20Street&address2=Apt%201&app_level=5&auth_code=&auth_date=20080125&auth_msg=%20Invalid%20Credit%20Card%20Number%2e%7c&authtype=authonly&card_address1=1234%20My%20Street&card_amount=1%2e00&card_city=Ottawa&card_country=CA&card_name=Longbob%20Longsen&card_state=ON&card_type=failure&card_zip=K1C2N6&city=Ottawa&convert=underscores&country=CA&currency=usd&dontsndmail=yes&easycart=0&errdetails=card%2dnumber%7cCard%20Number%20fails%20LUHN%20%2d%2010%20check%2e%7c&errlevel=1&merchant=pnpdemo2&mode=auth&orderID=2008012522275901541&phone=555%2d555%2d5555&publisher_email=trash%40plugnpay%2ecom&publisher_name=pnpdemo2&publisher_password=pnpdemo222&resp_code=P55&shipinfo=0&shipname=Jim%20Smith&sresp=E&state=ON&success=no&zip=K1C2N6&MErrMsg=Invalid%20Credit%20Card%20Number%2e%7c&a=b\n"
  end
end
