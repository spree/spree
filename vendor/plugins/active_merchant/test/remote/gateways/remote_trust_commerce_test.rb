require File.dirname(__FILE__) + '/../../test_helper'

class TrustCommerceTest < Test::Unit::TestCase
  def setup
    @gateway = TrustCommerceGateway.new(fixtures(:trust_commerce))
    
    @credit_card = credit_card('4111111111111111')
    
    @amount = 100
    
    @valid_verification_value = '123'
    @invalid_verification_value = '1234'
    
    @valid_address = {
      :address1 => '123 Test St.', 
      :address2 => nil, 
      :city => 'Somewhere', 
      :state => 'CA', 
      :zip => '90001'
    }
    
    @invalid_address = {
      :address1 => '187 Apple Tree Lane.',
      :address2 => nil,
      :city => 'Woodside',
      :state => 'CA',
      :zip => '94062'
    }
    
    @options = { 
      :ip => '10.10.10.10',
      :order_id => '#1000.1',
      :email => 'cody@example.com', 
      :billing_address => @valid_address,
      :shipping_address => @valid_address
    }
  end
  
  def test_bad_login
    @gateway.options[:login] = 'X'
    assert response = @gateway.purchase(@amount, @credit_card, @options)
        
    assert_equal Response, response.class
    assert_equal ["error",
                  "offenders",
                  "status"], response.params.keys.sort

    assert_match /A field was improperly formatted, such as non-digit characters in a number field/, response.message
    
    assert_failure response
  end
  
  def test_successful_purchase_with_avs
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'Y', response.avs_result['code']
    assert_match /The transaction was successful/, response.message
    
    assert_success response
    assert !response.authorization.blank?
  end
  
  def test_unsuccessful_purchase_with_invalid_cvv
    @credit_card.verification_value = @invalid_verification_value
    assert response = @gateway.purchase(@amount, @credit_card, @options)
        
    assert_equal Response, response.class
    assert_match /CVV failed; the number provided is not the correct verification number for the card/, response.message
    assert_failure response
  end
    
  def test_purchase_with_avs_for_invalid_address
    assert response = @gateway.purchase(@amount, @credit_card, @options.update(:billing_address => @invalid_address))
    assert_equal "N", response.params["avs"]
    assert_match /The transaction was successful/, response.message
    assert_success response
  end
  
  def test_successful_authorize_with_avs
    assert response = @gateway.authorize(@amount, @credit_card, :billing_address => @valid_address)
    
    assert_equal "Y", response.avs_result["code"]
    assert_match /The transaction was successful/, response.message

    assert_success response
    assert !response.authorization.blank?
  end
  
  def test_unsuccessful_authorize_with_invalid_cvv
    @credit_card.verification_value = @invalid_verification_value
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_match /CVV failed; the number provided is not the correct verification number for the card/, response.message
    assert_failure response
  end
  
  def test_authorization_with_avs_for_invalid_address
    assert response = @gateway.authorize(@amount, @credit_card, @options.update(:billing_address => @invalid_address))
    assert_equal "N", response.params["avs"]
    assert_match /The transaction was successful/, response.message
    assert_success response
  end
  
  def test_successful_capture
    auth = @gateway.authorize(300, @credit_card)
    assert_success auth
    response = @gateway.capture(300, auth.authorization)
    
    assert_success response
    assert_equal 'The transaction was successful', response.message 
    assert_equal 'accepted', response.params['status']
    assert response.params['transid']
  end
  
  def test_authorization_and_void
    auth = @gateway.authorize(300, @credit_card, @options)
    assert_success auth
    
    void = @gateway.void(auth.authorization)
    assert_success void
    assert_equal 'The transaction was successful', void.message 
    assert_equal 'accepted', void.params['status']
    assert void.params['transid']
  end
  
  def test_successful_credit
    assert response = @gateway.credit(@amount, '011-0022698151')
    
    assert_match /The transaction was successful/, response.message
    assert_success response    
  end
  
  def test_store_failure
    assert response = @gateway.store(@credit_card)
        
    assert_equal Response, response.class
    assert_match %r{The merchant can't accept data passed in this field}, response.message    
    assert_failure response   
  end
  
  def test_unstore_failure
    assert response = @gateway.unstore('testme')

    assert_match %r{The merchant can't accept data passed in this field}, response.message    
    assert_failure response
  end
  
  def test_recurring_failure
    assert response = @gateway.recurring(@amount, @credit_card, :periodicity => :weekly)

    assert_match %r{The merchant can't accept data passed in this field}, response.message    
    assert_failure response
  end
end