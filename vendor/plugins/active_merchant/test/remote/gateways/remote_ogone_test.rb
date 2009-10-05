require 'test_helper'

class RemoteOgoneTest < Test::Unit::TestCase

  def setup
    @gateway = OgoneGateway.new(fixtures(:ogone))
    @amount = 100
    @credit_card =   credit_card('4000100011112224')
    @declined_card = credit_card('1111111111111111')
    @options = {
      :order_id => generate_unique_id[0...30],
      :billing_address => address,
      :description => 'Store Purchase'
    }
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal OgoneGateway::SUCCESS_MESSAGE, response.message
  end

  def test_successful_purchase_without_order_id
    @options.delete(:order_id)
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal OgoneGateway::SUCCESS_MESSAGE, response.message
  end

  def test_unsuccessful_purchase
    assert response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'no brand', response.message
  end

  def test_authorize_and_capture
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_equal OgoneGateway::SUCCESS_MESSAGE, auth.message
    assert auth.authorization
    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
  end

  def test_unsuccessful_capture
    assert response = @gateway.capture(@amount, '')
    assert_failure response
    assert_equal 'no card no, no exp date, no brand', response.message
  end

  def test_successful_void
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert auth.authorization
    assert void = @gateway.void(auth.authorization)
    assert_equal OgoneGateway::SUCCESS_MESSAGE, auth.message
    assert_success void
  end

  def test_successful_referenced_credit
    assert purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase
    assert credit = @gateway.credit(@amount, purchase.authorization, @options)
    assert_success credit
    assert credit.authorization
    assert_equal OgoneGateway::SUCCESS_MESSAGE, credit.message
  end

  def test_unsuccessful_referenced_credit
    assert purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase
    assert credit = @gateway.credit(@amount+1, purchase.authorization, @options) # too much refund requested
    assert_failure credit
    assert credit.authorization
    assert_equal 'Overflow in refunds requests/1/1', credit.message
  end

  def test_successful_unreferenced_credit
    assert credit = @gateway.credit(@amount, @credit_card, @options)
    assert_success credit
    assert credit.authorization
    assert_equal OgoneGateway::SUCCESS_MESSAGE, credit.message
  end

  def test_reference_transactions
    # Setting an alias
    assert response = @gateway.purchase(@amount, credit_card('4000100011112224'), @options.merge(:store => "awesomeman", :order_id=>Time.now.to_i.to_s+"1"))
    assert_success response
    # Updating an alias
    assert response = @gateway.purchase(@amount, credit_card('4111111111111111'), @options.merge(:store => "awesomeman", :order_id=>Time.now.to_i.to_s+"2"))
    assert_success response
    # Using an alias (i.e. don't provide the credit card)
    assert response = @gateway.purchase(@amount, "awesomeman", @options.merge(:order_id=>Time.now.to_i.to_s+"3"))
    assert_success response
  end

  def test_invalid_login
    gateway = OgoneGateway.new(
                :login => '',
                :user => '',
                :password => ''
              )
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'no pspid', response.message
  end

end