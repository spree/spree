require 'test_helper'

class RemoteFirstPayTest < Test::Unit::TestCase
  def setup
    @gateway = FirstPayGateway.new(fixtures(:first_pay))
    
    @amount = 100
    @credit_card = credit_card('4111111111111111', {:first_name => 'Test', :last_name => 'Person'})
    @declined_card = credit_card('4111111111111111')
    
    @options = { 
      :order_id => '1',
      :billing_address => address({:name => 'Test Person', :city => 'New York', :state => 'NY', :zip => '10002', :country => 'US'}),
      :description => 'Test Purchase'
    }
  end
  
  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal('CAPTURED', response.message)
  end

  def test_unsuccessful_purchase
    # > $500 results in decline
    @amount = 51000
    assert response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal("51-INSUFFICIENT FUNDS", response.message)
  end
  
  def test_invalid_login
    gateway = FirstPayGateway.new(:login => '', :password => '')
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal '703-INVALID VENDOR ID AND PASS CODE', response.message
  end
  
  def test_successful_credit
    # purchase first
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal('CAPTURED', response.message)
    assert_not_nil(response.params["auth"])
    assert_not_nil(response.authorization)
    
    @options[:credit_card] = @credit_card
    
    assert response = @gateway.credit(@amount, response.authorization, @options)
    assert_success response
    assert_not_nil(response.authorization)
  end
  
  def test_failed_credit
    @options[:credit_card] = @credit_card
    
    assert response = @gateway.credit(@amount, '000000', @options)
    assert_failure response
    assert_nil(response.authorization)
    assert_equal('PARENT TRANSACTION NOT FOUND', response.message)
  end
  
  def test_failed_unlinked_credit
    assert_raise ArgumentError do
      @gateway.credit(@amount, @credit_card)
    end
  end
  
  def test_successful_void
    # purchase first
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal('CAPTURED', response.message)
    assert_not_nil(response.params["auth"])
    assert_not_nil(response.authorization)
    
    assert_success response
    assert_not_nil(response.authorization)
  end
  
  def test_failed_void    
    assert response = @gateway.void(@amount, @credit_card, @options)
    assert_failure response
    assert_equal('PARENT TRANSACTION NOT FOUND', response.message)
  end
  
end
