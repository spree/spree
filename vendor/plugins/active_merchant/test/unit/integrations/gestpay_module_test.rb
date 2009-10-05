require 'test_helper'

class GestpayModuleTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations
  
  def test_notification_method
    Gestpay::Notification.any_instance.expects(:ssl_get).returns('#decryptstring#a=9000000&b=PAY1_UICCODE=242*P1*PAY1_AMOUNT=1234.56*P1*PAY1_TRANSACTIONRESULT=OK*P1*PAY1_BANKTRANSACTIONID=ABCD1234*P1*PAY1_SHOPTRANSACTIONID=1000#/decryptstring#')
    assert_instance_of Gestpay::Notification, Gestpay.notification('a=900000&b=F7DEB36478FD84760F9134F23C922697272D57DE6D4518EB9B4D468B769D9A3A8071B6EB160B35CB412FC1820C7CC12D17B3141855B1ED55468613702A2E213DDE9DE5B0209E13C416448AE833525959F05693172D7F0656')
  end
  
  def test_return_method
    assert_instance_of Gestpay::Return, Gestpay.return('name=cody')
  end
end 
