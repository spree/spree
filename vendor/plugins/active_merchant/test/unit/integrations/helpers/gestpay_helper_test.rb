require 'test_helper'

class GestpayHelperTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations
  
  def setup
    @helper = Gestpay::Helper.new('order-500','1234567', :amount => '5.00', :currency => 'EUR')
  end
 
  def test_basic_helper_fields
    assert_field 'ShopLogin', '1234567'
    assert_field 'PAY1_AMOUNT', '5.00'
    assert_field 'PAY1_SHOPTRANSACTIONID', 'order-500'
    assert_field 'PAY1_UICCODE', '242'
  end
  
  def test_italian_currency
    @helper = Gestpay::Helper.new('order-500','1234567', :amount => '5.00', :currency => 'ITL')
    assert_field 'PAY1_UICCODE', '18'
  end
  
  def test_invalid_currency
    assert_raise(StandardError) do
      Gestpay::Helper.new('order-500','1234567', :amount => '5.00', :currency => 'CAD')
    end
  end
  
  def test_customer_fields
    @helper.customer :first_name => 'Cody', :last_name => 'Fauser', :email => 'cody@example.com'
    assert_field 'PAY1_CHNAME', 'Cody Fauser'
    assert_field 'PAY1_CHEMAIL', 'cody@example.com'
  end
  
  def test_get_encryption_string
    @helper.expects(:ssl_get).returns(encrypted_string_response)
    assert_equal encrypted_string, @helper.send(:get_encrypted_string)
  end
  
  def test_get_encryption_string_fails
    @helper.expects(:ssl_get).returns('#error#1132-Not accepted call: shop is not in active state#/error#\r\n')
    
    assert_raise(StandardError) do
      @helper.send(:get_encrypted_string)
    end
  end
  
  def test_get_encryption_string_returns_empty_response
    @helper.expects(:ssl_get).returns('')
    
    assert_raise(StandardError) do
      @helper.send(:get_encrypted_string)
    end
  end
  
  def test_form_fields
    @helper.expects(:ssl_get).returns(encrypted_string_response)
    assert_equal '1234567', @helper.form_fields['a']
    assert_equal encrypted_string, @helper.form_fields['b']
  end

  # Doesn't do any address mapping
  def test_address_mapping
    assert_nothing_raised do
      @helper.billing_address :address1 => '1 My Street',
                              :address2 => '',
                              :city => 'Leeds',
                              :state => 'Yorkshire',
                              :zip => 'LS2 7EE',
                              :country  => 'CA'
    end
  end
  
  def test_unknown_address_mapping
    total_fields = @helper.fields.size
    @helper.billing_address :farm => 'CA'
    assert_equal total_fields, @helper.fields.size
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
  
  private
  
  def encrypted_string_response
    '#cryptstring#F7DEB36478FD84760F9134F23C922697272D57DE6D4518EB9B4D468B769D9A3A8071B6EB160B35CB412FC1820C7CC12D17B3141855B1ED55468613702A2E213DDE9DE5B0209E13C416448AE833525959F05693172D7F0656#/cryptstring#'
  end
  
  def encrypted_string
    'F7DEB36478FD84760F9134F23C922697272D57DE6D4518EB9B4D468B769D9A3A8071B6EB160B35CB412FC1820C7CC12D17B3141855B1ED55468613702A2E213DDE9DE5B0209E13C416448AE833525959F05693172D7F0656'
  end
end
