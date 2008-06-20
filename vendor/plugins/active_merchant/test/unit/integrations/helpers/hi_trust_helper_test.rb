require File.dirname(__FILE__) + '/../../../test_helper'

class HiTrustHelperTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations
  
  def setup
    @helper = HiTrust::Helper.new('order-500','cody@example.com', :amount => 500, :currency => 'USD')
  end
 
  def test_basic_helper_fields
    assert_field 'storeid', 'cody@example.com'
    assert_field 'amount', '500'
    assert_field 'ordernumber', 'order-500'
    assert_field 'currency', 'USD'
  end
end
