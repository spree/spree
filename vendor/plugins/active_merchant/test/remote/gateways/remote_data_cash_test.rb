# Author::    MoneySpyder, www.moneyspyder.co.uk
require File.dirname(__FILE__) + '/../../test_helper'

class RemoteDataCashTest < Test::Unit::TestCase

  def setup
    # gateway to connect to Datacash
    @gateway = DataCashGateway.new(fixtures(:data_cash))

    @mastercard = CreditCard.new(
      :number => '5473000000000007',
      :month => 3,
      :year => Date.today.year + 2,              
      :first_name => 'Mark',      
      :last_name => 'McBride',
      :type => :master,
      :verification_value => '547'
    )

    @mastercard_declined = CreditCard.new(
      :number => '5473000000000106',
      :month => 3,
      :year => Date.today.year + 2,              
      :first_name => 'Mark',      
      :last_name => 'McBride',
      :type => :master,
      :verification_value => '547'
    )

    @visa_delta = CreditCard.new(
      :number => '4539792100000003',
      :month => 3,
      :year => Date.today.year + 2,              
      :first_name => 'Mark',      
      :last_name => 'McBride',
      :type => :visa,
      :verification_value => '444'
    )

    @solo = CreditCard.new(
      :first_name => 'Cody',
      :last_name => 'Fauser',
      :number => '633499100000000004',
      :month => 3,
      :year => Date.today.year + 2,
      :type => :solo,
      :issue_number => 5,
      :start_month => 12,
      :start_year => 2006,
      :verification_value => 444
    )

    @address = { 
      :name     => 'Mark McBride',
      :address1 => 'Flat 12/3',
      :address2 => '45 Main Road',
      :city     => 'Sometown',
      :state    => 'Somecounty',
      :zip      => 'A987AA',
      :phone    => '(555)555-5555'
    }

    @params = {
      :order_id => generate_unique_id,
      :billing_address => @address
    }

    @amount = 198
  end

  # Testing that we can successfully make a purchase in a one step
  # operation
  def test_successful_purchase
    response = @gateway.purchase(@amount, @mastercard, @params)
    assert_success response
    assert response.test?
  end

  #the amount is changed to £1.99 - the DC test server won't check the
  #address details - this is more a check on the passed ExtendedPolicy
  def test_successful_purchase_without_address_check
    response = @gateway.purchase(199, @mastercard, @params)
    assert_success response
    assert response.test?
  end

  # Note the Datacash test server regularly times out on switch requests
  def test_successful_purchase_with_solo_card
    response = @gateway.purchase(@amount, @solo, @params)
    assert_success response
    assert response.test?
  end

  # this card number won't check the address details - testing extended
  # policy
  def test_successful_purchase_without_address_check2
    @solo.number = '633499110000000003'

    response = @gateway.purchase(@amount, @solo, @params)
    assert_success response
    assert response.test?
  end

  # Testing purchase with request to set up recurring payment account
  def test_successful_purchase_without_account_set_up_and_repeat_payments
    response = @gateway.purchase(@amount, @mastercard, @params)
    assert_success response
    assert response.authorization.to_s.split(';')[2].blank?
    assert response.test?    
  end

  # Testing purchase with request to set up recurring payment account
  def test_successful_purchase_with_account_set_up_and_repeat_payments
    @params[:set_up_continuous_authority] = true
    response = @gateway.purchase(@amount, @mastercard, @params)
    assert_success response
    assert !response.authorization.to_s.split(';')[2].blank?
    assert response.test?

    #Make second payment on the continuous authorization that was set up in the first purchase
    second_order_params = { :order_id => generate_unique_id }
    purchase = @gateway.purchase(201, response.params['ca_reference'], second_order_params)
    assert_success purchase
    assert purchase.test?
  end

  def test_successful_purchase_with_account_set_up_and_repeat_payments_with_visa_delta_card
    @params[:set_up_continuous_authority] = true
    response = @gateway.purchase(@amount, @visa_delta, @params)
    assert_success response
    assert !response.authorization.to_s.split(';')[2].blank? 
    assert response.test?

    #Make second payment on the continuous authorization that was set up in the first purchase
    second_order_params = { :order_id => generate_unique_id }
    purchase = @gateway.purchase(201, response.params['ca_reference'], second_order_params)
    assert_success purchase
    assert purchase.test?
  end

  def test_purchase_with_account_set_up_for_repeat_payments_fails_for_solo_card
    @params[:set_up_continuous_authority] = true
    response = @gateway.purchase(@amount, @solo, @params)
    assert_equal '92', response.params['status'] # Error code for CA not supported
    assert_equal 'CA Not Supported', response.message 
    assert response.test?
  end

  def test_successful_authorization_and_capture_with_account_set_up_and_second_purchase
    #Authorize first payment
    @params[:set_up_continuous_authority] = true
    first_authorization = @gateway.authorize(@amount, @mastercard, @params)
    assert_success first_authorization
    assert !first_authorization.authorization.to_s.split(';')[2].blank?
    assert first_authorization.test?

    #Capture first payment
    capture = @gateway.capture(@amount, first_authorization.authorization, @params)
    assert_success capture
    assert capture.test?

    #Collect second purchase
    second_order_params = { :order_id => generate_unique_id }
    purchase = @gateway.purchase(201, first_authorization.authorization, second_order_params)
    assert_success purchase
    assert purchase.test?
  end

  def test_duplicate_order_id
    response = @gateway.purchase(@amount, @mastercard, @params)
    assert_success response

    duplicate_response = @gateway.purchase(@amount, @mastercard, @params)
    assert_failure duplicate_response
    assert_equal 'Duplicate reference', duplicate_response.message
    assert duplicate_response.test?
  end

  def test_invalid_verification_number
    @mastercard.verification_value = 123
    response = @gateway.purchase(@amount, @mastercard, @params)
    assert_failure response
    assert_equal 'CV2AVS DECLINED', response.message
    assert response.test?
  end

  def test_invalid_expiry_month
    @mastercard.month = 13
    response = @gateway.purchase(@amount, @mastercard, @params)
    assert_failure response
    assert_equal 'Expiry date invalid', response.message
    assert response.test?
  end

  def test_invalid_expiry_year
    @mastercard.year = 1999
    response = @gateway.purchase(@amount, @mastercard, @params)
    assert_failure response
    assert_equal 'Card has already expired', response.message
    assert response.test?
  end

  def test_declined_card
    response = @gateway.purchase(@amount, @mastercard_declined, @params)
    assert_failure response
    assert_equal 'DECLINED', response.message
    assert response.test?
  end

  def test_successful_authorization_and_capture    
    authorization = @gateway.authorize(@amount, @mastercard, @params)
    assert_success authorization
    assert authorization.test?

    capture = @gateway.capture(@amount, authorization.authorization, @params)
    assert_success capture
    assert capture.test?
  end

  def test_unsuccessful_capture
    response = @gateway.capture(@amount, ';1234', @params)
    assert_failure response
    assert_equal 'AUTHCODE field required', response.message
    assert response.test?
  end

  def test_successful_authorization_and_void    
    authorization = @gateway.authorize(@amount, @mastercard, @params)
    assert_success authorization
    assert authorization.test?

    void = @gateway.void(authorization.authorization, @params)
    assert_success void
    assert void.test?
  end

  def test_successfully_purchase_and_void
    purchase = @gateway.purchase(@amount, @mastercard, @params)
    assert_success purchase
    assert purchase.test?

    void = @gateway.void(purchase.authorization, @params)
    assert_success void
    assert void.test?
  end
  
  
  def test_successful_refund
    response = @gateway.credit(@amount, @mastercard, @params)
    assert_success response
    assert !response.params['datacash_reference'].blank?
    assert !response.params['merchantreference'].blank?
    
    assert response.test?
  end

  def test_successful_transaction_refund
    purchase = @gateway.purchase(@amount, @mastercard, @params)
    assert_success purchase
    assert purchase.test?

    refund = @gateway.credit(@amount, purchase.params['datacash_reference'])
    assert_success refund
    assert !refund.params['datacash_reference'].blank?
    assert !refund.params['merchantreference'].blank?
    
    assert refund.test?
  end

  def test_successful_transaction_refund_with_money_set_to_nil
    purchase = @gateway.purchase(@amount, @mastercard, @params)
    assert_success purchase
    assert purchase.test?

    refund = @gateway.credit(nil, purchase.params['datacash_reference'])
    assert_success refund
    assert refund.test?
  end

  def test_successful_transaction_refund_in_two_stages
    purchase = @gateway.purchase(@amount, @mastercard, @params)
    assert_success purchase
    assert purchase.test?

    first_partial_refund = @gateway.credit(100, purchase.params['datacash_reference'])
    assert_success first_partial_refund
    assert first_partial_refund.test?

    second_partial_refund = @gateway.credit(98, purchase.params['datacash_reference'])
    assert_success second_partial_refund
    assert second_partial_refund.test?
  end

  def test_successful_partial_transaction_refund
    purchase = @gateway.purchase(@amount, @mastercard, @params)
    assert_success purchase
    assert purchase.test?

    partial_refund = @gateway.credit(100, purchase.params['datacash_reference'])
    assert_success partial_refund
    assert partial_refund.test?
  end

  def test_fail_to_refund_too_much
    purchase = @gateway.purchase(@amount, @mastercard, @params)
    assert_success purchase
    assert purchase.test?

    refund_too_much = @gateway.credit(500, purchase.params['datacash_reference'])
    assert_failure refund_too_much
    assert_equal 'Refund amount > orig 1.98', refund_too_much.message
    assert refund_too_much.test?
  end

  def test_fail_to_refund_with_declined_purchase_reference    
    declined_purchase = @gateway.purchase(@amount, @mastercard_declined, @params)
    assert_failure declined_purchase
    assert declined_purchase.test?

    refund = @gateway.credit(@amount, declined_purchase.params['datacash_reference'])
    assert_failure refund
    assert_equal 'Cannot refund transaction', refund.message
    assert refund.test?
  end

  def test_fail_to_refund_purchase_which_is_already_refunded    
    purchase = @gateway.purchase(@amount, @mastercard, @params)
    assert_success purchase
    assert purchase.test?

    first_refund = @gateway.credit(nil, purchase.params['datacash_reference'])
    assert_success first_refund
    assert first_refund.test?

    second_refund = @gateway.credit(@amount, purchase.params['datacash_reference'])
    assert_failure second_refund
    assert_equal '1.98 > remaining funds 0.00', second_refund.message
    assert second_refund.test?
  end

  # Check short merchant references are reformatted
  def test_merchant_reference_that_is_too_short
    @params[:order_id] = @params[:order_id].first(5)
    response = @gateway.purchase(@amount, @mastercard, @params)
    assert_success response
    assert response.test?
  end

  # Check long merchant references are reformatted
  def test_merchant_reference_that_is_too_long
    @params[:order_id] =  "#{@params[:order_id]}1234356"
    response = @gateway.purchase(@amount, @mastercard, @params)
    assert_success response
    assert response.test?
  end

end
