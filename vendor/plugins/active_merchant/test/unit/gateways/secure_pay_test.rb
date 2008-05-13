require File.dirname(__FILE__) + '/../../test_helper'

class SecurePayTest < Test::Unit::TestCase

  def setup
    @gateway = SecurePayGateway.new(
      :login => 'X',
      :password => 'Y'
    )

    @credit_card = credit_card
    
    @options = {
      :order_id => generate_unique_id,
      :description => 'Store purchase',
      :billing_address => address
    }
    
    @amount = 100
  end

  def test_failed_purchase
    @gateway.stubs(:ssl_post).returns(failure_response)
    
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
    assert_equal 'This transaction has been declined', response.message
    assert_equal '3377475', response.authorization
  end
  
  def test_successful_purchase
    @gateway.stubs(:ssl_post).returns(successful_purchase_response)
    
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert response.test?
    assert_equal 'This transaction has been approved', response.message
    assert response.authorization
  end
  
  
  def test_avs_result
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    
    response = @gateway.purchase(@amount, @credit_card)
    assert_equal 'X', response.avs_result['code']
  end
  
  def test_cvv_result_not_supported
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    
    response = @gateway.purchase(@amount, @credit_card)
    assert_nil response.cvv_result['code']
  end
  
  
  def test_undefine_unsupported_methods
    assert @gateway.respond_to?(:purchase)
    
    [ :authorize, :capture, :void, :credit ].each do |m|
      assert !@gateway.respond_to?(m)
    end
  end
  
  def test_supported_countries_are_inherited
    assert_equal AuthorizeNetGateway.supported_countries, SecurePayGateway.supported_countries
  end
  
  def test_supported_card_types_are_inherited
    assert_equal AuthorizeNetGateway.supported_cardtypes, SecurePayGateway.supported_cardtypes
  end
  
  private
  
  def successful_purchase_response
    '1%%1%This transaction has been approved.%100721%X%3377575%f6af895031c07d88399ed9fdb48c8476%Store+purchase%0.01%%AUTH_CAPTURE%%Cody%Fauser%%100+Example+St.%Ottawa%ON%K2A5P7%Canada%%%%%%%%%%%%%%%%%%%'
  end

  def failure_response
    '2%%2%This transaction has been declined.%NOT APPROVED%U%3377475%55adbbaed13aa7e2526846d672fdb594%Store+purchase%1.00%%AUTH_CAPTURE%%Longbob%Longsen%%1234+Test+St.%Ottawa%ON%K1N5P8%Canada%%%%%%%%%%%%%%%%%%%'
  end
  
  def failed_capture_response
    '3%%6%The credit card number is invalid.%%%%%%0.01%%PRIOR_AUTH_CAPTURE%%%%%%%%%%%%%%%%%%%%%%%%%%%%'
  end
end
