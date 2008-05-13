require File.dirname(__FILE__) + '/../../test_helper'

class TrustCommerceTest < Test::Unit::TestCase
  def setup
    @gateway = TrustCommerceGateway.new(
      :login => 'TestMerchant',
      :password => 'password'
    )
    # Force SSL post
    @gateway.stubs(:tclink?).returns(false)

    @amount = 100
    @credit_card = credit_card('4111111111111111')
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    assert response = @gateway.purchase(@amount, @credit_card)
    assert_instance_of Response, response
    assert_success response
    assert_equal '025-0007423614', response.authorization
  end

  def test_unsuccessful_purchase
    @gateway.expects(:ssl_post).returns(unsuccessful_purchase_response)
    assert response = @gateway.purchase(@amount, @credit_card)
    assert_instance_of Response, response
    assert_failure response
  end
   
  def test_amount_style   
   assert_equal '1034', @gateway.send(:amount, 1034)
                                                  
   assert_raise(ArgumentError) do
     @gateway.send(:amount, '10.34')
   end
  end
  
  def test_avs_result
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    
    response = @gateway.purchase(@amount, @credit_card)
    assert_equal 'Y', response.avs_result['code']
  end
  
  def test_cvv_result
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    
    response = @gateway.purchase(@amount, @credit_card)
    assert_equal 'P', response.cvv_result['code']
  end
  
  def test_supported_countries
    assert_equal ['US'], TrustCommerceGateway.supported_countries
  end

  def test_supported_card_types
    assert_equal [:visa, :master, :discover, :american_express, :diners_club, :jcb], TrustCommerceGateway.supported_cardtypes
  end
  
  def successful_purchase_response
    <<-RESPONSE
transid=025-0007423614
status=approved
avs=Y
cvv=P
    RESPONSE
  end
  
  def unsuccessful_purchase_response
    <<-RESPONSE
transid=025-0007423827
declinetype=cvv
status=decline
cvv=N
    RESPONSE
  end
end
