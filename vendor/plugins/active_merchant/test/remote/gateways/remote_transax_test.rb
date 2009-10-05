require 'test_helper'

class RemoteTransaxTest < Test::Unit::TestCase
  def setup
    @gateway = TransaxGateway.new(fixtures(:transax))
    
    @amount = 100
    @credit_card = credit_card('4111111111111111', :year => 10, :month => 10)
    @declined_card = credit_card(0xDEADBEEF_0000.to_s)
    
    @check = check()
    
    @options = { 
      :order_id => '1',
      :billing_address => address,
      :description => 'Store Purchase'
    }
  end
  
  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal "This transaction has been approved", response.message
  end
  
  def test_unsuccessful_purchase
    assert response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_match /Invalid card number/, response.message
  end
  
  def test_authorize_and_capture
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_equal "This transaction has been approved", auth.message
    assert auth.authorization
    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
  end
  
  def test_authorize_and_void
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_equal "This transaction has been approved", auth.message
    assert auth.authorization
    assert void = @gateway.void(auth.authorization)
    assert_equal "Transaction Void Successful", void.message
    assert_success void
  end
  
  def test_purchase_and_refund
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal "This transaction has been approved", response.message
    assert response.authorization
    assert refund = @gateway.refund(response.authorization)
    assert_equal "This transaction has been approved", refund.message
    assert_success refund
  end
  
  def test_failed_capture
    assert response = @gateway.capture(@amount, '')
    assert_failure response
    assert_match /Invalid Transaction ID/, response.message
  end
  
  def test_credit
    assert response = @gateway.credit(@amount, @credit_card, @options)
    assert_success response
    assert response.authorization
    assert_equal "This transaction has been approved", response.message
  end
  
  def test_purchase_and_update
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal "This transaction has been approved", response.message
    assert response.authorization
    assert update = @gateway.amend(response.authorization, :shipping_carrier => 'usps')
    assert_equal "This transaction has been approved", update.message
    assert_success update
  end
  
  def test_successful_purchase_with_sku
    @options['product_sku_#']='123456'
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal "This transaction has been approved", response.message
  end
  
  def test_store_credit_card
    assert response = @gateway.store(@credit_card)
    assert_success response
    assert !response.params['customer_vault_id'].blank?
  end
  
  def test_store_check
    assert response = @gateway.store(@check)
    assert_success response
    assert !response.params['customer_vault_id'].blank?
  end
  
  def test_invalid_login
    gateway = TransaxGateway.new(
                :login => '',
                :password => ''
              )
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal "Invalid Username", response.message
  end
end
