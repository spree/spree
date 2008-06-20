require File.dirname(__FILE__) + '/../../test_helper'

class RemotePaypalIntegrationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def test_raw
    assert_equal "https://www.sandbox.paypal.com/cgi-bin/webscr", Paypal.service_url
    @paypal = Paypal::Notification.new('')
    
    assert_nothing_raised do
      assert_equal false, @paypal.acknowledge  
    end
  end
end
