require 'test_helper'

class PslCardTest < Test::Unit::TestCase

  def setup
    @gateway = PslCardGateway.new(
                 :login => 'LOGIN',
                 :password => 'PASSWORD'
               )

    @credit_card = credit_card  
    @options = {
      :billing_address => address,
      :description => 'Store purchase'
    }
    @amount = 100
  end
  
  def test_successful_authorization
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal '08012522454901256086', response.authorization
    assert response.test?
  end

  def test_unsuccessful_request
    @gateway.expects(:ssl_post).returns(unsuccessful_purchase_response)
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  def test_supported_countries
    assert_equal ['GB'], PslCardGateway.supported_countries
  end
  
  def test_supported_card_types
    assert_equal [ :visa, :master, :american_express, :diners_club, :jcb, :switch, :solo, :maestro ], PslCardGateway.supported_cardtypes
  end
  
  def test_avs_result
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)    
    assert_equal 'Y', response.avs_result['code']
  end

  def test_cvv_result
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'M', response.cvv_result['code']
  end
  
  private
  def successful_purchase_response
    "ResponseCode=00&Message=AUTHCODE:01256&CrossReference=08012522454901256086&First4=4543&Last4=9982&ExpMonth=12&ExpYear=2010&AVSCV2Check=ALL MATCH&Amount=1000&QAAddress=76 Roseby Avenue Manchester&QAPostcode=M63X 7TH&MerchantName=Merchant Name&QAName=John Smith"
  end
  
  def unsuccessful_purchase_response
    "ResponseCode=05&Message=CARD DECLINED&QAAddress=The Parkway Larches Approach Hull North Humberside&QAPostcode=HU7 9OP&MerchantName=Merchant Name&QAName="
  end
end