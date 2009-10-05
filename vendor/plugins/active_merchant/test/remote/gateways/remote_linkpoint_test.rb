#
# In order for this test to pass, a valid store number and PEM file 
# are required. Unfortunately, with LinkPoint YOU CAN'T JUST USE ANY 
# OLD STORE NUMBER. Also, you can't just generate your own PEM file. 
# You'll need to use a special PEM file provided by LinkPoint. 
#
# Go to http://www.linkpoint.com/support/sup_teststore.asp to set up 
# a test account.  Once you receive your test account you can get your
# pem file by clicking the Support link on the navigation menu and then
# clicking the Download Center link.
#
# You will also want to change your test account's fraud settings
# while running these tests.  Click the admin link at the top of 
# LinkPoint Central.  Then click "set lockout times" under Fraud Settings
# You will want to set Duplicate lockout time to 0 so that you can run
# the tests more than once without triggering this fraud detection.
#
# The LinkPoint staging server will also return different responses based
# on the cent amount of the purhcase. Complete details can be found at
require 'test_helper'

# http://sgserror.com/staging.php
class LinkpointTest < Test::Unit::TestCase
  def setup
    Base.mode = :test
    
    @gateway = LinkpointGateway.new(fixtures(:linkpoint))
        
    # Test credit card numbers
    # American Express: 371111111111111
    # Discover: 6011-1111-1111-1111
    # JCB: 311111111111111
    # MasterCard: 5111-1111-1111-1111
    # MasterCard: 5419-8400-0000-0003
    # Visa: 4111-1111-1111-1111

    @amount = 100
    @credit_card = credit_card('4111111111111111')
    @options = { :order_id => generate_unique_id, :billing_address => address }
  end
  
  def test_successful_authorization
    assert response = @gateway.authorize(1000, @credit_card, @options)
    
    assert_instance_of Response, response
    assert_success response
    assert_equal "APPROVED", response.params["approved"]
  end
  
  def test_successful_authorization_and_capture
    assert authorization = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorization
    assert authorization.test?
    
    assert capture = @gateway.capture(@amount, authorization.authorization)
    assert_success capture
    assert_equal 'ACCEPTED', capture.message
  end
  
  def test_successful_purchase_without_cvv2_code
    @credit_card.verification_value = nil
    
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal "APPROVED", response.params["approved"]
    assert_equal 'NNN', response.params["avs"]
  end
  
  def test_successful_purchase_with_cvv2_code
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal "APPROVED", response.params["approved"]
    assert_equal 'NNNM', response.params["avs"]
  end
  
  def test_successful_purchase_and_void
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase
    
    assert void = @gateway.void(purchase.authorization)
    assert_success void
  end
  
  def test_successfull_purchase_and_credit
    assert purchase = @gateway.purchase(2400, @credit_card, @options)
    assert_success purchase
    
    assert credit = @gateway.credit(2400, purchase.authorization)
    assert_success credit
  end

  
  def test_successful_recurring_payment
    assert response = @gateway.recurring(2400, @credit_card, 
      :order_id => generate_unique_id, 
      :installments => 12,
      :startdate => "immediate",
      :periodicity => :monthly,
      :billing_address => address
    )
    
    assert_success response
    assert_equal "APPROVED", response.params["approved"]
  end
  
  def test_declined_purchase_with_invalid_credit_card
    @credit_card.number = '1111111111111111'
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal "DECLINED", response.params["approved"]
  end
end
