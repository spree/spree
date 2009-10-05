require 'test_helper'

class BogusModuleTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations
  
  def test_notification_method
    assert_instance_of Bogus::Notification, Bogus.notification('name=cody')
  end

  def test_service_url
    new = 'http://www.unbogus.com'
    assert_equal 'http://www.bogus.com', Bogus.service_url
    Bogus.service_url = new
    assert_equal new, Bogus.service_url
  end
  
  def test_return_method
    assert_instance_of Bogus::Return, Bogus.return('name=cody')
  end
end 
