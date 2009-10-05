require 'test_helper'

class VerifiTest < Test::Unit::TestCase
  include ActiveMerchant::Billing

  def setup
    @gateway = VerifiGateway.new(
      :login => 'l',
      :password => 'p'
    )
    
    @credit_card = credit_card('4111111111111111')
    
    @options = {
      :order_id => '37',
      :email => "paul@example.com",   
      :billing_address => address     
    }
    
    @amount = 100
  end

  def test_successful_request
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal '546061538', response.authorization
    assert response.test?
  end

  def test_unsuccessful_request
    @gateway.expects(:ssl_post).returns(unsuccessful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end
  
  def test_amount_style
    assert_equal '10.34', @gateway.send(:amount, 1034)
                                                      
    assert_raise(ArgumentError) do
     @gateway.send(:amount, '10.34')
    end
  end
                                                 
  def test_add_description
    result = {}
    @gateway.send(:add_invoice_data, result, :description => 'My Purchase is great')
    assert_equal 'My Purchase is great', result[:orderdescription]
    
  end

  def test_purchase_meets_minimum_requirements
    post = VerifiGateway::VerifiPostData.new
    post[:amount] = "1.01"                                          
  
    @gateway.send(:add_credit_card, post, @credit_card)
                                                       
    assert data = @gateway.send(:post_data, :authorization, post)
    
    minimum_requirements.each do |key| 
      assert_not_nil(data =~ /#{key}=/)
    end
    
  end
  
  def test_avs_result
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'N', response.avs_result['code']
  end
  
  def test_cvv_result
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'N', response.cvv_result['code']
  end

  private
  
  def minimum_requirements
    %w(type username password ccnumber ccexp amount)
  end
  
  def successful_purchase_response
    "response=1&responsetext=SUCCESS&authcode=123456&transactionid=546061538&avsresponse=N&cvvresponse=N&orderid=37&type=sale&response_code=100"
  end

  def unsuccessful_purchase_response
    "response=3&responsetext=Field required: ccnumber REFID:12109909&authcode=&transactionid=0&avsresponse=&cvvresponse=&orderid=37&type=sale&response_code=300"
  end
end
