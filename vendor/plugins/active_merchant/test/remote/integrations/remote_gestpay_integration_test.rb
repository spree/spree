require 'test_helper'

class RemoteGestpayIntegrationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    # Your Gestpay ShopLogin
    @shop_login = 'SHOPLOGIN'
    
    @helper = Gestpay::Helper.new('order-500', @shop_login, :amount => '5.00', :currency => 'EUR')
  end

  def test_get_encryption_string
    # Extra fields don't work yet
    # @helper.customer :first_name => 'Cody', :last_name => 'Fauser', :email => 'codyfauser@gmail.com'
    response = @helper.send(:get_encrypted_string)
    assert !response.blank?
  end
  
  def test_get_encryption_string_fails
    @helper = Gestpay::Helper.new('order-500','99999999', :amount => '5.00', :currency => 'EUR')
    assert_raise(StandardError) do
      assert @helper.send(:get_encrypted_string).blank?
    end
  end
  
  def test_unknown_shop_for_decryption_request
    assert_raise(StandardError) do 
      Gestpay::Notification.new(raw_query_string)
    end
  end
  
  private
  def raw_query_string
    "a=900000&b=F7DEB36478FD84760F9134F23C922697272D57DE6D4518EB9B4D468B769D9A3A8071B6EB160B35CB412FC1820C7CC12D17B3141855B1ED55468613702A2E213DDE9DE5B0209E13C416448AE833525959F05693172D7F0656"
  end
end
