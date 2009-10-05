require 'test_helper'

# This test suite assumes that you have enabled username/password transaction validation in your Beanstream account.
# You will experience some test failures if username/password validation transaction validation is not enabled.
class RemoteBeanstreamTest < Test::Unit::TestCase
  
  def setup
    @gateway = BeanstreamGateway.new(fixtures(:beanstream))
    
    # Beanstream test cards. Cards require a CVV of 123, which is the default of the credit card helper
    @visa                = credit_card('4030000010001234')
    @declined_visa       = credit_card('4003050500040005')
    
    @mastercard          = credit_card('5100000010001004')
    @declined_mastercard = credit_card('5100000020002000')
    
    @amex                = credit_card('371100001000131')
    @declined_amex       = credit_card('342400001000180')
    
    # Canadian EFT
    @check               = check(
                             :institution_number => '001',
                             :transit_number     => '26729'
                           )
    
    @amount = 1500
    
    @options = { 
      :order_id => generate_unique_id,
      :billing_address => {
        :name => 'xiaobo zzz',
        :phone => '555-555-5555',
        :address1 => '1234 Levesque St.',
        :address2 => 'Apt B',
        :city => 'Montreal',
        :state => 'QC',
        :country => 'CA',
        :zip => 'H2C1X8'
      },
      :email => 'xiaobozzz@example.com',
      :subtotal => 800,
      :shipping => 100,
      :tax1 => 100,
      :tax2 => 100,
      :custom => 'reference one'
    }
  end
  
  def test_successful_visa_purchase
    assert response = @gateway.purchase(@amount, @visa, @options)
    assert_success response
    assert_false response.authorization.blank?
    assert_equal "Approved", response.message
  end

  def test_unsuccessful_visa_purchase
    assert response = @gateway.purchase(@amount, @declined_visa, @options)
    assert_failure response
    assert_equal 'DECLINE', response.message
  end
  
  def test_successful_mastercard_purchase
    assert response = @gateway.purchase(@amount, @mastercard, @options)
    assert_success response
    assert_false response.authorization.blank?
    assert_equal "Approved", response.message
  end

  def test_unsuccessful_mastercard_purchase
    assert response = @gateway.purchase(@amount, @declined_mastercard, @options)
    assert_failure response
    assert_equal 'DECLINE', response.message
  end
  
  def test_successful_amex_purchase
    assert response = @gateway.purchase(@amount, @amex, @options)
    assert_success response
    assert_false response.authorization.blank?
    assert_equal "Approved", response.message
  end

  def test_unsuccessful_amex_purchase
    assert response = @gateway.purchase(@amount, @declined_amex, @options)
    assert_failure response
    assert_equal 'DECLINE', response.message
  end

  def test_authorize_and_capture
    assert auth = @gateway.authorize(@amount, @visa, @options)
    assert_success auth
    assert_equal "Approved", auth.message
    assert_false auth.authorization.blank?
    
    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert_false capture.authorization.blank?
  end
  
  def test_failed_capture
    assert response = @gateway.capture(@amount, '')
    assert_failure response
    assert_no_match %r{You are not authorized}, response.message, "You need to enable username/password validation"
    assert_match %r{Missing or invalid adjustment id.}, response.message
  end
  
  def test_successful_purchase_and_void
    assert purchase = @gateway.purchase(@amount, @visa, @options)
    assert_success purchase
    
    assert void = @gateway.void(purchase.authorization)
    assert_success void
  end
  
  def test_successful_purchase_and_credit_and_void_credit
    assert purchase = @gateway.purchase(@amount, @visa, @options)
    assert_success purchase
    
    assert credit = @gateway.credit(@amount, purchase.authorization)
    assert_success purchase
    
    assert void = @gateway.void(credit.authorization)
    assert_success void
  end
  
  def test_successful_check_purchase
    assert response = @gateway.purchase(@amount, @check, @options)
    assert_success response
    assert response.test?
    assert_false response.authorization.blank?
  end
  
  def test_successful_check_purchase_and_credit
    assert purchase = @gateway.purchase(@amount, @check, @options)
    assert_success purchase
    
    assert credit = @gateway.credit(@amount, purchase.authorization)
    assert_success credit
  end
  
  def test_invalid_login
    gateway = BeanstreamGateway.new(
                :merchant_id => '',
                :login => '',
                :password => ''
              )
    assert response = gateway.purchase(@amount, @visa, @options)
    assert_failure response
    assert_equal 'Invalid merchant id (merchant_id = 0)', response.message
  end
end
