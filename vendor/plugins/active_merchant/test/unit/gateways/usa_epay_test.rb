require File.dirname(__FILE__) + '/../../test_helper'

class UsaEpayTest < Test::Unit::TestCase
  def setup
    @gateway = UsaEpayGateway.new(
                :login => 'LOGIN'
               )

    @credit_card = credit_card('4242424242424242')
    @options = {
      :billing_address => address,
      :shipping_address => address
    }
    @amount = 100
  end
  
  def test_successful_request
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal '55074409', response.authorization
    assert response.test?
  end

  def test_unsuccessful_request
    @gateway.expects(:ssl_post).returns(unsuccessful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  def test_address_key_prefix
    assert_equal 'bill', @gateway.send(:address_key_prefix, :billing)
    assert_equal 'ship', @gateway.send(:address_key_prefix, :shipping)
    assert_nil @gateway.send(:address_key_prefix, :vacation)
  end

  def test_address_key
    assert_equal :shipfname, @gateway.send(:address_key, 'ship', 'fname')
  end

  def test_add_address
    post = {}
    @gateway.send(:add_address, post, @credit_card, @options)
    assert_address(:shipping, post)
    assert_equal 20, post.keys.size
  end
  
  def test_add_billing_address
    post = {}
    @gateway.send(:add_address, post, @credit_card, @options)
    assert_address(:billing, post)
    assert_equal 20, post.keys.size
  end
  
  def test_add_billing_and_shipping_addresses
    post = {}
    @gateway.send(:add_address, post, @credit_card, @options)
    assert_address(:shipping, post)
    assert_address(:billing, post)
    assert_equal 20, post.keys.size
  end
  
  def test_amount_style
   assert_equal '10.34', @gateway.send(:amount, 1034)
                                                      
   assert_raise(ArgumentError) do
     @gateway.send(:amount, '10.34')
   end
  end
  
  def test_supported_countries
    assert_equal ['US'], UsaEpayGateway.supported_countries
  end

  def test_supported_card_types
    assert_equal [:visa, :master, :american_express], UsaEpayGateway.supported_cardtypes
  end
  
  def test_avs_result
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'Y', response.avs_result['code']
    assert_equal 'Y', response.avs_result['street_match']
    assert_equal 'Y', response.avs_result['postal_match']
  end
  
  def test_cvv_result
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'M', response.cvv_result['code']
  end

  private
  def assert_address(type, post) 
    prefix = key_prefix(type)
    assert_equal @credit_card.first_name, post[key(prefix, 'fname')]
    assert_equal @credit_card.last_name, post[key(prefix, 'lname')]
    assert_equal @options[:billing_address][:company], post[key(prefix, 'company')]
    assert_equal @options[:billing_address][:address1], post[key(prefix, 'street')]
    assert_equal @options[:billing_address][:address2], post[key(prefix, 'street2')]
    assert_equal @options[:billing_address][:city], post[key(prefix, 'city')]
    assert_equal @options[:billing_address][:state], post[key(prefix, 'state')]
    assert_equal @options[:billing_address][:zip], post[key(prefix, 'zip')]
    assert_equal @options[:billing_address][:country], post[key(prefix, 'country')]
    assert_equal @options[:billing_address][:phone], post[key(prefix, 'phone')]
  end
  
  def key_prefix(type)
    @gateway.send(:address_key_prefix, type)
  end

  def key(prefix, key)
    @gateway.send(:address_key, prefix, key)
  end
  
  def successful_purchase_response
    "UMversion=2.9&UMstatus=Approved&UMauthCode=001716&UMrefNum=55074409&UMavsResult=Address%3A%20Match%20%26%205%20Digit%20Zip%3A%20Match&UMavsResultCode=YYY&UMcvv2Result=Match&UMcvv2ResultCode=M&UMresult=A&UMvpasResultCode=&UMerror=Approved&UMerrorcode=00000&UMcustnum=&UMbatch=596&UMisDuplicate=N&UMconvertedAmount=&UMconvertedAmountCurrency=840&UMconversionRate=&UMcustReceiptResult=No%20Receipt%20Sent&UMfiller=filled"
  end
  
  def unsuccessful_purchase_response
    "UMversion=2.9&UMstatus=Declined&UMauthCode=000000&UMrefNum=55076060&UMavsResult=Address%3A%20Match%20%26%205%20Digit%20Zip%3A%20Match&UMavsResultCode=YYY&UMcvv2Result=Not%20Processed&UMcvv2ResultCode=P&UMvpasResultCode=&UMresult=D&UMerror=Card%20Declined&UMerrorcode=10127&UMbatch=596&UMfiller=filled"
  end
end
