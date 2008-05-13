require File.dirname(__FILE__) + '/../../../test_helper'

class GestpayNotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def test_successful_notification
    Gestpay::Notification.any_instance.expects(:ssl_get).returns('#decryptstring#PAY1_UICCODE=242*P1*PAY1_AMOUNT=1234.56*P1*PAY1_TRANSACTIONRESULT=OK*P1*PAY1_BANKTRANSACTIONID=ABCD1234*P1*PAY1_SHOPTRANSACTIONID=1000#/decryptstring#')
    notification = Gestpay::Notification.new(raw_query_string)
    assert notification.complete?
    assert !notification.test?
    assert_equal "Completed", notification.status
    assert_equal "ABCD1234", notification.transaction_id
    assert_equal "1000", notification.item_id
    assert_equal "1234.56", notification.gross
    assert_equal "EUR", notification.currency
    assert_equal Money.new(123456, 'EUR'), notification.amount
  end
  
  def test_failed_notification
    Gestpay::Notification.any_instance.expects(:ssl_get).returns('#decryptstring#PAY1_UICCODE=242*P1*PAY1_AMOUNT=1234.56*P1*PAY1_TRANSACTIONRESULT=KO*P1*PAY1_BANKTRANSACTIONID=ABCD1234*P1*PAY1_SHOPTRANSACTIONID=1000#/decryptstring#')
    notification = Gestpay::Notification.new(raw_query_string)
    assert !notification.complete?
    assert !notification.test?
    assert_equal "Failed", notification.status
  end
  
  def test_empty_notification
    Gestpay::Notification.any_instance.stubs(:ssl_get).returns('')
    notification = Gestpay::Notification.new('')
    assert !notification.complete?
    assert !notification.test?
    assert_equal "Failed", notification.status
  end
  
  def test_nil_notification
    Gestpay::Notification.any_instance.stubs(:ssl_get).returns('')
    notification = Gestpay::Notification.new(nil)
    assert !notification.complete?
    assert !notification.test?
    assert_equal "Failed", notification.status
  end
  
  def test_abandoned_order
    Gestpay::Notification.any_instance.expects(:ssl_get).returns(unencrypted_string)
    notification = Gestpay::Notification.new(raw_query_string)
    assert !notification.complete?
    assert !notification.test?
    assert_equal "Failed", notification.status
    assert_equal '1000', notification.item_id
  end

  private
  def raw_query_string
    "a=900000&b=F7DEB36478FD84760F9134F23C922697272D57DE6D4518EB9B4D468B769D9A3A8071B6EB160B35CB412FC1820C7CC12D17B3141855B1ED55468613702A2E213DDE9DE5B0209E13C416448AE833525959F05693172D7F0656"
  end
  
  def unencrypted_string
    "#decryptstring#PAY1_TRANSACTIONRESULT=KO*P1*PAY1_SHOPTRANSACTIONID=1000*P1*PAY1_BANKTRANSACTIONID=*P1*PAY1_UICCODE=242*P1*PAY1_AMOUNT=50.00*P1*PAY1_AUTHORIZATIONCODE=*P1*PAY1_ERRORCODE=1143*P1*PAY1_ERRORDESCRIPTION=Transazione abbandonata dal compratore*P1*PAY1_CHEMAIL=*P1*PAY1_CHNAME=#/decryptstring#\r\n"
  end
end
