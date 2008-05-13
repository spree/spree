require File.dirname(__FILE__) + '/../../test_helper'

class PaypalTest < Test::Unit::TestCase
  def setup
    Base.gateway_mode = :test
    
    @gateway = PaypalGateway.new(fixtures(:paypal_certificate))

    @creditcard = CreditCard.new(
      :type                => "visa",
      :number              => "4381258770269608", # Use a generated CC from the paypal Sandbox
      :verification_value => "000",
      :month               => 1,
      :year                => Time.now.year + 1,
      :first_name          => 'Fred',
      :last_name           => 'Brooks'
    )
       
    @params = {
      :order_id => generate_unique_id,
      :email => 'buyer@jadedpallet.com',
      :billing_address => { :name => 'Fred Brooks',
                    :address1 => '1234 Penny Lane',
                    :city => 'Jonsetown',
                    :state => 'NC',
                    :country => 'US',
                    :zip => '23456'
                  } ,
      :description => 'Stuff that you purchased, yo!',
      :ip => '10.0.0.1'
    }
      
    @amount = 100
    # test re-authorization, auth-id must be more than 3 days old.
    # each auth-id can only be reauthorized and tested once.
    # leave it commented if you don't want to test reauthorization.
    # 
    #@three_days_old_auth_id  = "9J780651TU4465545" 
    #@three_days_old_auth_id2 = "62503445A3738160X" 
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @creditcard, @params)
    assert_success response
    assert response.params['transaction_id']
  end
  
  def test_successful_purchase_with_api_signature
    gateway = PaypalGateway.new(fixtures(:paypal_signature))
    response = gateway.purchase(@amount, @creditcard, @params)
    assert_success response
    assert response.params['transaction_id']
  end
  
  def test_failed_purchase
    @creditcard.number = '234234234234'
    response = @gateway.purchase(@amount, @creditcard, @params)
    assert_failure response
    assert_nil response.params['transaction_id']
  end

  def test_successful_authorization
    response = @gateway.authorize(@amount, @creditcard, @params)
    assert_success response
    assert response.params['transaction_id']
    assert_equal '1.00', response.params['amount']
    assert_equal 'USD', response.params['amount_currency_id']
  end
  
  def test_failed_authorization
    @creditcard.number = '234234234234'
    response = @gateway.authorize(@amount, @creditcard, @params)
    assert_failure response
    assert_nil response.params['transaction_id']
  end

  def test_successful_reauthorization
    return if not @three_days_old_auth_id
    auth = @gateway.reauthorize(1000, @three_days_old_auth_id)
    assert_success auth
    assert auth.authorization
    
    response = @gateway.capture(1000, auth.authorization)
    assert_success response
    assert response.params['transaction_id']
    assert_equal '10.00', response.params['gross_amount']
    assert_equal 'USD', response.params['gross_amount_currency_id']
  end
  
  def test_failed_reauthorization
    return if not @three_days_old_auth_id2  # was authed for $10, attempt $20
    auth = @gateway.reauthorize(2000, @three_days_old_auth_id2)
    assert_false auth?
    assert !auth.authorization
  end
      
  def test_successful_capture
    auth = @gateway.authorize(@amount, @creditcard, @params)
    assert_success auth
    response = @gateway.capture(@amount, auth.authorization)
    assert_success response
    assert response.params['transaction_id']
    assert_equal '1.00', response.params['gross_amount']
    assert_equal 'USD', response.params['gross_amount_currency_id']
  end
  
  def test_successful_voiding
    auth = @gateway.authorize(@amount, @creditcard, @params)
    assert_success auth
    response = @gateway.void(auth.authorization)
    assert_success response
  end
  
  def test_purchase_and_full_credit
    purchase = @gateway.purchase(@amount, @creditcard, @params)
    assert_success purchase
    
    credit = @gateway.credit(@amount, purchase.authorization, :note => 'Sorry')
    assert_success credit
    assert credit.test?
    assert_equal 'USD',  credit.params['net_refund_amount_currency_id']
    assert_equal '0.67', credit.params['net_refund_amount']
    assert_equal 'USD',  credit.params['gross_refund_amount_currency_id']
    assert_equal '1.00', credit.params['gross_refund_amount']
    assert_equal 'USD',  credit.params['fee_refund_amount_currency_id']
    assert_equal '0.33', credit.params['fee_refund_amount']
  end
  
  def test_failed_voiding
    response = @gateway.void('foo')
    assert_failure response
  end
  
  def test_successful_transfer
    response = @gateway.purchase(@amount, @creditcard, @params)
    assert_success response
    
    response = @gateway.transfer(@amount, 'joe@example.com', :subject => 'Your money', :note => 'Thanks for taking care of that')
    assert_success response
  end

  def test_failed_transfer
     # paypal allows a max transfer of $10,000
    response = @gateway.transfer(1000001, 'joe@example.com')
    assert_failure response
  end
  
  def test_successful_multiple_transfer
    response = @gateway.purchase(900, @creditcard, @params)
    assert_success response
    
    response = @gateway.transfer([@amount, 'joe@example.com'],
      [600, 'jane@example.com', {:note => 'Thanks for taking care of that'}],
      :subject => 'Your money')
    assert_success response
  end
  
  def test_failed_multiple_transfer
    response = @gateway.purchase(25100, @creditcard, @params)
    assert_success response

    # You can only include up to 250 recipients
    recipients = (1..251).collect {|i| [100, "person#{i}@example.com"]}
    response = @gateway.transfer(*recipients)
    assert_failure response
  end
end
