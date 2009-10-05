require 'test_helper'

class RemoteSkipJackTest < Test::Unit::TestCase
  def setup
    Base.mode = :test

    @gateway = SkipJackGateway.new(fixtures(:skip_jack))

    @credit_card = credit_card('4445999922225',
                    :verification_value => '999'
                  )

    @amount = 100
    
    @options = {
      :order_id => generate_unique_id,
      :email => 'email@foo.com',
      :billing_address => address
    }
  end
  
  def test_successful_authorization
    authorization = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorization
    assert_false authorization.authorization.blank?
  end
  
  def test_unsuccessful_authorization
    @credit_card.number = '1234'
    authorization = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure authorization
  end
  
  def test_authorization_fails_without_phone_number
    @options[:billing_address][:phone] = nil
    authorization = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure authorization
  end
  
  def test_successful_purchase
    assert_success @gateway.purchase(@amount, @credit_card, @options)
  end

  def test_successful_authorization_and_capture
    authorization = @gateway.authorize(@amount, @credit_card, @options)
    
    assert_success authorization
    assert_false authorization.authorization.blank?
    
    capture = @gateway.capture(@amount, authorization.authorization)
    assert_success capture
  end
  
  def test_authorization_and_void
    authorization = @gateway.authorize(101, @credit_card, @options)
    assert_success authorization
    void = @gateway.void(authorization.authorization)
    assert_success void
  end

  def test_successful_authorization_and_credit
    authorization = @gateway.authorize(@amount, @credit_card, @options)    
    assert_success authorization
    
    capture = @gateway.capture(@amount, authorization.authorization, :force_settlement => true)
    assert_success capture 

    # developer login won't change transaction immediately to settled, so status will have to mismatch
    credit = @gateway.credit(@amount, authorization.authorization)
    assert_success credit
  end

  def test_authorization_with_invalid_verification_value
    @credit_card.verification_value = '123'
    
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert_equal "Card verification number didn't match", response.message
  end

  def test_authorization_and_status
    authorization = @gateway.authorize(101, @credit_card, @options)
    assert_success authorization
    
    status = @gateway.status(@options[:order_id])
    assert_success status
  end

  def test_status_unkown_order
    status = @gateway.status(generate_unique_id)
    assert_failure status
    assert_match /No Records Found/, status.message
  end
  
  def test_invalid_login
    gateway = SkipJackGateway.new(
                :login => '555555555555',
                :password => '999999999999'
              )

    response = gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert_match /Invalid serial number/, response.message
  end
end
