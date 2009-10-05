require 'test_helper'

class NochexHelperTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations
  
  def setup
    @helper = Nochex::Helper.new('order-500','cody@example.com', :amount => 500, :currency => 'GBP')
  end
 
  def test_basic_helper_fields
    assert_field 'email', 'cody@example.com'

    # Nochex requires 2 decimal places on the amount
    assert_field 'amount', '5.00'
    assert_field 'ordernumber', 'order-500'
  end
  
  def test_customer_fields
    @helper.customer :first_name => 'Cody', :last_name => 'Fauser', :email => 'cody@example.com'
    assert_field 'firstname', 'Cody'
    assert_field 'lastname', 'Fauser'
    assert_field 'email_address_sender', 'cody@example.com'
  end

  def test_address_mapping
    @helper.billing_address :address1 => '1 My Street',
                            :city => 'Leeds',
                            :state => 'Yorkshire',
                            :zip => 'LS2 7EE'
   
    assert_field 'firstline', '1 My Street'
    assert_field 'town', 'Leeds'
    assert_field 'county', 'Yorkshire'
    assert_field 'postcode', 'LS2 7EE'
  end
  
  def test_unknown_address_mapping
    @helper.billing_address :country => 'CA'
    assert_equal 3, @helper.fields.size
  end

  def test_unknown_mapping
    assert_nothing_raised do
      @helper.company_address :address => '500 Dwemthy Fox Road'
    end
  end
  
  def test_setting_invalid_address_field
    fields = @helper.fields.dup
    @helper.billing_address :street => 'My Street'
    assert_equal fields, @helper.fields
  end
end
