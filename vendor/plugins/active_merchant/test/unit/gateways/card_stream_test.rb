require 'test_helper'

class CardStreamTest < Test::Unit::TestCase
  def setup
    @gateway = CardStreamGateway.new(
      :login => 'LOGIN',
      :password => 'PASSWORD'
    )
    
    @amount = 100
    @credit_card = credit_card('4242424242424242')
    @options = { :order_id => '1', :billing_address => address }
  end
  
  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response
    assert_equal '08010706065208191057', response.authorization
  end
  
  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)
    
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_failure response
  end
  
  def test_successful_avs_result
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'Y', response.avs_result['street_match']
    assert_equal 'Y', response.avs_result['postal_match']
  end
  
  def test_failed_avs_result
    @gateway.expects(:ssl_post).returns(successful_purchase_failed_avs_cvv_response)
    
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'N', response.cvv_result['code']
    assert_equal 'N', response.avs_result['street_match']
    assert_equal 'N', response.avs_result['postal_match']
  end
  
  def test_cvv_result
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'M', response.cvv_result['code']
  end
  
  def test_supported_countries
    assert_equal ['GB'], CardStreamGateway.supported_countries
  end
  
  def test_supported_card_types
    assert_equal [:visa, :master, :american_express, :diners_club, :discover, :jcb, :maestro, :solo, :switch], CardStreamGateway.supported_cardtypes
  end
  
  def test_default_currency
    params = {}
    
    @gateway.send(:add_amount, params, 1000, {})
    assert_equal '826', params[:CurrencyCode]
  end
  
  def test_override_currency
    params = {}
    
    @gateway.send(:add_amount, params, 1000, :currency => 'USD')
    assert_equal '840', params[:CurrencyCode]
  end
  
  private
  def successful_purchase_response
    'VPResponseCode=00&VPCrossReference=08010706065208191057&VPMessage=AUTHCODE:08191&VPTransactionUnique=c3871e2d005b924bf81565537caba82d&VPOrderDesc=Store purchase&VPBillingCountry=826&VPCardName=Longbob Longsen&VPBillingPostCode=LE10 2RT&VPAmountRecieved=100&VPAVSCV2ResponseCode=222100&VPCV2ResultMessage=CV2 Matched&VPAVSResultMessage=Postcode Matched&VPAVSAddressMessage=Address Numeric Matched&VPCardType=MC&VPBillingAddress=25 The Larches, Narborough, Leicester&VPReturnPoint=0090'
  end
  
  def successful_purchase_failed_avs_cvv_response
    'VPResponseCode=00&VPCrossReference=08010706065208191057&VPMessage=AUTHCODE:08191&VPTransactionUnique=c3871e2d005b924bf81565537caba82d&VPOrderDesc=Store purchase&VPBillingCountry=826&VPCardName=Longbob Longsen&VPBillingPostCode=LE10 2RT&VPAmountRecieved=100&VPAVSCV2ResponseCode=444100&VPCV2ResultMessage=CV2 Matched&VPAVSResultMessage=Postcode Matched&VPAVSAddressMessage=Address Numeric Matched&VPCardType=MC&VPBillingAddress=25 The Larches, Narborough, Leicester&VPReturnPoint=0090'
  end
  
  def failed_purchase_response
    'VPResponseCode=05&VPCrossReference=NoCrossReference&VPMessage=CARD DECLINED&VPTransactionUnique=d966e18a2983faff3715a541983792e0&VPOrderDesc=Store purchase&VPBillingCountry=826&VPCardName=Longbob Longsen&VPBillingPostCode=LE10 2RT&VPAmountRecieved=NA&VPAVSCV2ResponseCode=222100&VPCV2ResultMessage=CV2 Matched&VPAVSResultMessage=Postcode Matched&VPAVSAddressMessage=Address Numeric Matched&VPCardType=MC&VPBillingAddress=25 The Larches, Narborough, Leicester&VPReturnPoint=0090'
  end
end