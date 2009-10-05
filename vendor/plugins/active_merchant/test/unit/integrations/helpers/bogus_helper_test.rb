require 'test_helper'

class BogusHelperTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations
  
  def setup
    @helper = Bogus::Helper.new('order-500','cfauser', :amount => 500, :currency => 'CAD')
  end

  def test_basic_helper_fields
    assert_field 'order', 'order-500'
    assert_field 'account', 'cfauser'
    assert_field 'amount', '500'
    assert_field 'currency', 'CAD'
  end
 
  def test_customer_fields 
    @helper.customer :first_name => 'Cody', :last_name => 'Fauser'
    assert_field 'first_name', 'Cody'
    assert_field 'last_name', 'Fauser'
  end

  def test_setting_unknown_field
    fields = @helper.fields.dup
    @helper.space_shuttle :name => 'Rockety'
    assert_equal fields, @helper.fields
  end
end
