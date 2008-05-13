# Author::    MoneySpyder, http://moneyspyder.co.uk

require File.dirname(__FILE__) + '/../../test_helper'

class RemotePslCardTest < Test::Unit::TestCase
  
  def setup
    @gateway = PslCardGateway.new(fixtures(:psl_card))
    
    @uk_maestro = CreditCard.new(fixtures(:psl_maestro))
    @uk_maestro_address = fixtures(:psl_maestro_address)
    
    @solo = CreditCard.new(fixtures(:psl_solo))
    @solo_address = fixtures(:psl_solo_address)
    
    @visa = CreditCard.new(fixtures(:psl_visa))
    @visa_address = fixtures(:psl_visa_address)
    
    # The test results are determined by the amount of the transaction
    @accept_amount = 1000
    @referred_amount = 6000
    @declined_amount = 11000
    @keep_card_amount = 15000
  end
  
  def test_successful_visa_purchase
    response = @gateway.purchase(@accept_amount, @visa,
      :billing_address => @visa_address
    )
    assert_success response
    assert response.test?
  end
  
  def test_successful_visa_purchase_specifying_currency
    response = @gateway.purchase(@accept_amount, @visa,
      :billing_address => @visa_address,
      :currency => 'GBP'
    )
    assert_success response
    assert response.test?
  end
  
  def test_successful_solo_purchase
    response = @gateway.purchase(@accept_amount, @solo, 
      :billing_address => @solo_address
    )
    assert_success response
    assert response.test?
  end
  
  def test_referred_purchase
    response = @gateway.purchase(@referred_amount, @uk_maestro, 
      :billing_address => @uk_maestro_address
    )
    assert_failure response
    assert response.test?
  end
  
  def test_declined_purchase
    response = @gateway.purchase(@declined_amount, @uk_maestro, 
      :billing_address => @uk_maestro_address
    )
    assert_failure response
    assert response.test?
  end
  
  def test_declined_keep_card_purchase
    response = @gateway.purchase(@keep_card_amount, @uk_maestro, 
      :billing_address => @uk_maestro_address
    )
    assert_failure response
    assert response.test?
  end
  
  def test_successful_authorization
    response = @gateway.authorize(@accept_amount, @uk_maestro, 
      :billing_address => @uk_maestro_address
    )
    assert_success response
    assert response.test?
  end
  
  def test_no_login
    @gateway = PslCardGateway.new(
      :login => ''
    )
    response = @gateway.authorize(@accept_amount, @uk_maestro, 
      :billing_address => @uk_maestro_address
    )
    assert_failure response
    assert response.test?
  end
  
  def test_successful_authorization_and_capture
    authorization = @gateway.authorize(@accept_amount, @uk_maestro,
      :billing_address => @uk_maestro_address
    )
    assert_success authorization
    assert authorization.test?
    
    capture = @gateway.capture(@accept_amount, authorization.authorization)
    
    assert_success capture
    assert capture.test?
  end
end
