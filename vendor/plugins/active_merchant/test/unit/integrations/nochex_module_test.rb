require 'test_helper'

class ChronopayModuleTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations
  
  def test_notification_method
    assert_instance_of Nochex::Notification, Nochex.notification('name=cody')
  end
  
  def test_return_method
    assert_instance_of Nochex::Return, Nochex.return('name=cody')
  end
end 
