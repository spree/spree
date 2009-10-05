require 'test_helper'

class RemoteCyberSourceTest < Test::Unit::TestCase
  def setup
    Base.gateway_mode = :test

    @gateway = CyberSourceGateway.new(fixtures(:cyber_source))

    @credit_card = credit_card('4111111111111111', :type => 'visa')
    @declined_card = credit_card('801111111111111', :type => 'visa')
    
    @amount = 100
    
    @options = {
      :billing_address => address,

      :order_id => generate_unique_id,
      :line_items => [
        {
          :declared_value => 100,
          :quantity => 2,
          :code => 'default',
          :description => 'Giant Walrus',
          :sku => 'WA323232323232323'
        },
        {
          :declared_value => 100,
          :quantity => 2,
          :description => 'Marble Snowcone',
          :sku => 'FAKE1232132113123'
        }
      ],  
      :currency => 'USD',
      :email => 'someguy1232@fakeemail.net',
      :ignore_avs => 'true',
      :ignore_cvv => 'true'
    }

  end
  
  def test_successful_authorization
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_equal 'Successful transaction', response.message
    assert_success response
    assert response.test?
    assert !response.authorization.blank?
  end

  def test_unsuccessful_authorization
    assert response = @gateway.authorize(@amount, @declined_card, @options)
    assert response.test?
    assert_equal 'Invalid account number', response.message
    assert_equal false,  response.success?
  end

  def test_successful_tax_calculation
    assert response = @gateway.calculate_tax(@credit_card, @options)
    assert_equal 'Successful transaction', response.message
    assert response.params['totalTaxAmount']
    assert_not_equal "0", response.params['totalTaxAmount']
    assert_success response
    assert response.test?
  end

  def test_successful_tax_calculation_with_nexus
    total_line_items_value = @options[:line_items].inject(0) do |sum, item| 
                               sum += item[:declared_value] * item[:quantity]
                             end
    
    canada_gst_rate = 0.05
    ontario_pst_rate = 0.08
    
    
    total_pst = total_line_items_value.to_f * ontario_pst_rate / 100
    total_gst = total_line_items_value.to_f * canada_gst_rate / 100
    total_tax = total_pst + total_gst
    
    assert response = @gateway.calculate_tax(@credit_card, @options.merge(:nexus => 'ON'))
    assert_equal 'Successful transaction', response.message
    assert response.params['totalTaxAmount']
    assert_equal total_pst, response.params['totalCountyTaxAmount'].to_f
    assert_equal total_gst, response.params['totalStateTaxAmount'].to_f
    assert_equal total_tax, response.params['totalTaxAmount'].to_f
    assert_success response
    assert response.test?
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'Successful transaction', response.message
    assert_success response
    assert response.test?
  end

  def test_unsuccessful_purchase
    assert response = @gateway.purchase(@amount, @declined_card, @options)
    assert_equal 'Invalid account number', response.message
    assert_failure response
    assert response.test?
  end

  def test_authorize_and_capture
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_equal 'Successful transaction', auth.message
  
    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
  end
  
  def test_successful_authorization_and_failed_capture
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_equal 'Successful transaction', auth.message

    assert capture = @gateway.capture(@amount + 10, auth.authorization, @options)
    assert_failure capture
    assert_equal "The requested amount exceeds the originally authorized amount",  capture.message
  end

  def test_failed_capture_bad_auth_info
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert capture = @gateway.capture(@amount, "a;b;c", @options)
    assert_failure capture
  end

  def test_invalid_login
    gateway = CyberSourceGateway.new( :login => '', :password => '' )
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_match /wsse:InvalidSecurity/, response.message
    assert_failure response
  end
  
  def test_successful_credit
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'Successful transaction', response.message
    assert_success response
    assert response.test?
    assert response = @gateway.credit(@amount, response.authorization)
    assert_equal 'Successful transaction', response.message
    assert_success response
    assert response.test?       
  end
end
