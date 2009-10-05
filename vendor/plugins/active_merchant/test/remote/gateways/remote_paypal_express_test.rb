require 'test_helper'

class PaypalExpressTest < Test::Unit::TestCase
  def setup
    Base.gateway_mode = :test
    
    @gateway = PaypalExpressGateway.new(fixtures(:paypal_certificate))
  
    @options = {
      :order_id => '230000',
      :email => 'buyer@jadedpallet.com',
      :billing_address => { :name => 'Fred Brooks',
                    :address1 => '1234 Penny Lane',
                    :city => 'Jonsetown',
                    :state => 'NC',
                    :country => 'US',
                    :zip => '23456'
                  } ,
      :description => 'Stuff that you purchased, yo!',
      :ip => '10.0.0.1',
      :return_url => 'http://example.com/return',
      :cancel_return_url => 'http://example.com/cancel'
    }
  end
  
  def test_set_express_authorization
    @options.update(
      :return_url => 'http://example.com',
      :cancel_return_url => 'http://example.com',
      :email => 'Buyer1@paypal.com'
    )
    response = @gateway.setup_authorization(500, @options)
    assert response.success?
    assert response.test?
    assert !response.params['token'].blank?
  end
  
  def test_set_express_purchase
    @options.update(
      :return_url => 'http://example.com',
      :cancel_return_url => 'http://example.com',
      :email => 'Buyer1@paypal.com'
    )
    response = @gateway.setup_purchase(500, @options)
    assert response.success?
    assert response.test?
    assert !response.params['token'].blank?
  end
end 
