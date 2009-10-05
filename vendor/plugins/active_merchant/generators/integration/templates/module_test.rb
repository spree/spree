require 'test_helper'

class <%= class_name %>ModuleTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations
  
  def test_notification_method
    assert_instance_of <%= class_name %>::Notification, <%= class_name %>.notification('name=cody')
  end
end 
