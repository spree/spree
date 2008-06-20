require File.dirname(__FILE__) + '/../../test_helper'

class PayJunctionTest < Test::Unit::TestCase
  include ActiveMerchant::Billing
  
  cattr_accessor :current_invoice
  
  AMOUNT = 250
  
  def setup
    @gateway = PayJunctionGateway.new(fixtures(:pay_junction))

    @credit_card = credit_card('4444333322221111', :verification_value => '123')
    
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
    
    @options = { :billing_address => @valid_address, :order_id => generate_unique_id }
  end
  
  def test_successful_purchase
    assert response = @gateway.purchase(AMOUNT, @credit_card, @options)
    assert_equal PayJunctionGateway::SUCCESS_MESSAGE, response.message
    assert_equal 'capture', response.params["posture"], 'Should be captured funds'
    assert_equal 'charge', response.params["transaction_action"]  
    assert_success response
    assert response.test?
  end

  def test_successful_purchase_with_cvv
    @credit_card.verification_value = @valid_verification_value
    assert response = @gateway.purchase(AMOUNT, @credit_card, @options)
        
    assert_equal PayJunctionGateway::SUCCESS_MESSAGE, response.message
    assert_equal 'capture', response.params["posture"], 'Should be captured funds'
    assert_equal 'charge', response.params["transaction_action"]
    
    assert_success response
  end

  def test_successful_authorize
    assert response = @gateway.authorize( AMOUNT, @credit_card, @options)
    
    assert_equal PayJunctionGateway::SUCCESS_MESSAGE, response.message
    assert_equal 'hold', response.params["posture"], 'Should be a held charge'
    assert_equal 'charge', response.params["transaction_action"]
    
    assert_success response    
  end

  def test_successful_capture
    auth = @gateway.authorize(AMOUNT, @credit_card, @options)
    assert_success auth

    response = @gateway.capture(AMOUNT, auth.authorization, @options)
    assert_success response
    assert_equal 'capture', response.params["posture"], 'Should be a capture'
    assert_equal auth.authorization, response.authorization,
        "Should maintain transaction ID across request"
  end

  def test_successful_credit
    purchase = @gateway.purchase(AMOUNT, @credit_card, @options)
    assert_success purchase
    
    assert response = @gateway.credit(success_price, purchase.authorization)
    assert_equal 'refund', response.params["transaction_action"]
    
    assert_success response    
  end

  def test_successful_void
    order_id = generate_unique_id
    purchase = @gateway.purchase(AMOUNT, @credit_card, @options)
    assert_success purchase
    
    assert response = @gateway.void(AMOUNT, purchase.authorization, :order_id => order_id)    
    assert_success response
    assert_equal 'void', response.params["posture"], 'Should be a capture'
    assert_equal purchase.authorization, response.authorization,
        "Should maintain transaction ID across request"
  end

  def test_successful_instant_purchase
    # this takes advatange of the PayJunction feature where another
    # transaction can be executed if you have the transaction ID of a
    # previous successful transaction.
    
    purchase = @gateway.purchase( AMOUNT, @credit_card, @options)
    assert_success purchase
    
    assert response = @gateway.purchase(AMOUNT, purchase.authorization, :order_id => generate_unique_id)
                                        
    assert_equal PayJunctionGateway::SUCCESS_MESSAGE, response.message
    assert_equal 'capture', response.params["posture"], 'Should be captured funds'
    assert_equal 'charge', response.params["transaction_action"]
    assert_not_equal purchase.authorization, response.authorization,
        'Should have recieved new transaction ID'
    
    assert_success response
  end

  def test_successful_recurring
    assert response = @gateway.recurring(AMOUNT, @credit_card, 
                        :periodicity  => :monthly,
                        :payments     => 12,
                        :order_id => generate_unique_id
                      )
    
    assert_equal PayJunctionGateway::SUCCESS_MESSAGE, response.message                                        
    assert_equal 'charge', response.params["transaction_action"]
    
    assert_success response
  end

  def test_should_send_invoice
    response = @gateway.purchase(AMOUNT, @credit_card, @options)
    assert_success response
    
    assert_equal @options[:order_id], response.params["invoice_number"], 'Should have set invoice'
  end

  private
  def success_price
    200 + rand(200)
  end
end