require 'test_helper'

class RemotePaypalIntegrationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @paypal = Paypal::Notification.new('')
  end

  def tear_down
    ActiveMerchant::Billing::Base.integration_mode = :test
  end
  
  def test_raw
    assert_equal "https://www.sandbox.paypal.com/cgi-bin/webscr", Paypal.service_url
    assert_nothing_raised do
      assert_equal false, @paypal.acknowledge
    end
  end
  
  def test_valid_sender_always_true
    ActiveMerchant::Billing::Base.integration_mode = :production
    assert @paypal.valid_sender?(nil)
    assert @paypal.valid_sender?('127.0.0.1')
  end
end
