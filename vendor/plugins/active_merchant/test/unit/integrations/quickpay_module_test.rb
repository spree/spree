require 'test_helper'

class QuickpayModuleTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations
  
  def test_notification_method
    assert_instance_of Quickpay::Notification, Quickpay.notification('name=cody')
  end
end 
