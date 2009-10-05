require 'test_helper'

class RemoteSageCheckTest < Test::Unit::TestCase
  
  def setup
    @gateway = SageVirtualCheckGateway.new(fixtures(:sage))
    
    @amount = 100
    @check = check
  
    @options = { 
      :order_id => generate_unique_id,
      :billing_address => address,
      :shipping_address => address,
      :email => 'longbob@example.com',
      :drivers_license_state => 'CA',
      :drivers_license_number => '12345689',
      :date_of_birth => Date.new(1978, 8, 11),
      :ssn => '078051120'
    }
  end
  
  def test_successful_check_purchase
    assert response = @gateway.purchase(@amount, @check, @options)
    assert_success response
    assert response.test?
    assert_false response.authorization.blank?
  end
  
  def test_failed_check_purchase
    @check.routing_number = ""
    
    assert response = @gateway.purchase(@amount, @check, @options)
    assert_failure response
    assert response.test?
    assert_false response.authorization.blank?
  end
  
  def test_purchase_and_void
    assert purchase = @gateway.purchase(@amount, @check, @options)
    assert_success purchase
    
    assert void = @gateway.void(purchase.authorization)
    assert_success void
  end
  
  def test_credit
    assert response = @gateway.credit(@amount, @check, @options)
    assert_success response
    assert response.test?
  end

  def test_invalid_login
    gateway = SageVirtualCheckGateway.new(
                :login => '',
                :password => ''
              )
    assert response = gateway.purchase(@amount, @check, @options)
    assert_failure response
    assert_equal 'SECURITY VIOLATION', response.message
  end
end
