require 'test_helper'

class RemoteQuickpayTest < Test::Unit::TestCase
  def setup  
    @gateway = QuickpayGateway.new(fixtures(:quickpay))

    @amount = 100
    @options = { 
      :order_id => generate_unique_id[0...10], 
      :billing_address => address
    }
    
    @visa_no_cvv2   = credit_card('4000300011112220', :verification_value => nil)
    @visa           = credit_card('4000100011112224')
    @dankort        = credit_card('5019717010103742')
    @visa_dankort   = credit_card('4571100000000000')
    @electron_dk    = credit_card('4175001000000000')
    @diners_club    = credit_card('30401000000000')
    @diners_club_dk = credit_card('36148010000000')
    @maestro        = credit_card('5020100000000000')
    @maestro_dk     = credit_card('6769271000000000')
    @mastercard_dk  = credit_card('5413031000000000')
    @amex_dk        = credit_card('3747100000000000')
    @amex           = credit_card('3700100000000000')
    
    # forbrugsforeningen doesn't use a verification value
    @forbrugsforeningen = credit_card('6007221000000000', :verification_value => nil)
  end
  
  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @visa, @options)
    assert_equal 'OK', response.message
    assert_equal 'DKK', response.params['currency']
    assert_success response
    assert !response.authorization.blank?
  end
  
  def test_successful_usd_purchase
    assert response = @gateway.purchase(@amount, @visa, @options.update(:currency => 'USD'))
    assert_equal 'OK', response.message
    assert_equal 'USD', response.params['currency']
    assert_success response
    assert !response.authorization.blank?
  end
  
  def test_successful_dankort_authorization
    assert response = @gateway.authorize(@amount, @dankort, @options)
    assert_success response
    assert !response.authorization.blank?
    assert_equal 'Dankort', response.params['cardtype']
  end
  
  def test_successful_visa_dankort_authorization
    assert response = @gateway.authorize(@amount, @visa_dankort, @options)
    assert_success response
    assert !response.authorization.blank?
    assert_equal 'Visa-Dankort', response.params['cardtype']
  end
  
  def test_successful_visa_electron_authorization
    assert response = @gateway.authorize(@amount, @electron_dk, @options)
    assert_success response
    assert !response.authorization.blank?
    assert_equal 'Visa-Electron-DK', response.params['cardtype']
  end
  
  def test_successful_diners_club_authorization
    assert response = @gateway.authorize(@amount, @diners_club, @options)    
    assert_success response
    assert !response.authorization.blank?
    assert_equal 'Diners', response.params['cardtype']
  end
  
  def test_successful_diners_club_dk_authorization
    assert response = @gateway.authorize(@amount, @diners_club_dk, @options)
    assert_success response
    assert !response.authorization.blank?
    assert_equal 'Diners-DK', response.params['cardtype']
  end
  
  def test_successful_maestro_authorization
    assert response = @gateway.authorize(@amount, @maestro, @options)
    assert_success response
    assert !response.authorization.blank?
    assert_equal 'Maestro', response.params['cardtype']
  end
  
  def test_successful_maestro_dk_authorization
    assert response = @gateway.authorize(@amount, @maestro_dk, @options)
    assert_success response
    assert !response.authorization.blank?
    assert_equal 'Maestro-DK', response.params['cardtype']
  end
  
  def test_successful_mastercard_dk_authorization
    assert response = @gateway.authorize(@amount, @mastercard_dk, @options)
    assert_success response
    assert !response.authorization.blank?
    assert_equal 'MasterCard-DK', response.params['cardtype']
  end
  
  def test_successful_american_express_dk_authorization
    assert response = @gateway.authorize(@amount, @amex_dk, @options)
    assert_success response
    assert !response.authorization.blank?
    assert_equal 'AmericanExpress-DK', response.params['cardtype']
  end

  def test_successful_american_express_authorization
    assert response = @gateway.authorize(@amount, @amex, @options)
    assert_success response
    assert !response.authorization.blank?
    assert_equal 'AmericanExpress', response.params['cardtype']
  end
  
  def test_successful_forbrugsforeningen_authorization
    assert response = @gateway.authorize(@amount, @forbrugsforeningen, @options)
    assert_success response
    assert !response.authorization.blank?
    assert_equal 'FBG-1886', response.params['cardtype']
  end
  
  def test_unsuccessful_purchase_with_missing_cvv2
    assert response = @gateway.purchase(@amount, @visa_no_cvv2, @options)
    # Quickpay has made the cvd field optional in order to support forbrugsforeningen cards which don't have them
    assert_equal 'OK', response.message
    assert_success response
    assert !response.authorization.blank?
  end

  def test_successful_authorize_and_capture
    assert auth = @gateway.authorize(@amount, @visa, @options)
    assert_success auth
    assert_equal 'OK', auth.message
    assert auth.authorization
    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert_equal 'OK', capture.message
  end

  def test_failed_capture
    assert response = @gateway.capture(@amount, '')
    assert_failure response
    assert_equal 'Missing field: transaction', response.message
  end
  
  def test_successful_purchase_and_void
    assert auth = @gateway.authorize(@amount, @visa, @options)
    assert_success auth
    assert_equal 'OK', auth.message
    assert auth.authorization
    assert void = @gateway.void(auth.authorization)
    assert_success void
    assert_equal 'OK', void.message
  end
  
  def test_successful_authorization_capture_and_credit
    assert auth = @gateway.authorize(@amount, @visa, @options)
    assert_success auth
    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert credit = @gateway.credit(@amount, auth.authorization)
    assert_success credit
    assert_equal 'OK', credit.message
  end
  
  def test_successful_purchase_and_credit
    assert purchase = @gateway.purchase(@amount, @visa, @options)
    assert_success purchase
    assert credit = @gateway.credit(@amount, purchase.authorization)
    assert_success credit
  end

  def test_successful_store_and_reference_purchase
    assert store = @gateway.store(@visa, @options.merge(:description => "New subscription"))
    assert_success store
    assert purchase = @gateway.purchase(@amount, store.authorization, @options.merge(:order_id => generate_unique_id[0...10]))
    assert_success purchase
  end

  def test_invalid_login
    gateway = QuickpayGateway.new(
        :login => '',
        :password => ''
    )
    assert response = gateway.purchase(@amount, @visa, @options)
    assert_equal 'Invalid merchant id', response.message
    assert_failure response
  end
end
