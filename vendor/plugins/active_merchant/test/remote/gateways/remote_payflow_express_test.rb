require 'test_helper'

class RemotePayflowTest < Test::Unit::TestCase
  def setup
    Base.gateway_mode = :test
    
    @gateway = PayflowExpressGateway.new(fixtures(:payflow))

    @options = { :billing_address => { 
                                :name => 'Cody Fauser',
                                :address1 => '1234 Shady Brook Lane',
                                :city => 'Ottawa',
                                :state => 'ON',
                                :country => 'CA',
                                :zip => '90210',
                                :phone => '555-555-5555'
                             },
                 :email => 'cody@example.com'
               }
  end
  
  # Only works with a Payflow 2.0 account or by requesting the addition
  # of Express checkout to an existing Payflow Pro account.  This can be done
  # by contacting Payflow sales. The PayPal account used must be a business
  # account and the Payflow Pro account must be in Live mode in order for
  # the tests to work correctly
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
