require 'test_helper'

class PaypalNotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @paypal = Paypal::Notification.new(http_raw_data)
  end

  def test_accessors
    assert @paypal.complete?
    assert_equal "Completed", @paypal.status
    assert_equal "6G996328CK404320L", @paypal.transaction_id
    assert_equal "web_accept", @paypal.type
    assert_equal "500.00", @paypal.gross
    assert_equal "15.05", @paypal.fee
    assert_equal "CAD", @paypal.currency
    assert_equal 'tobi@leetsoft.com' , @paypal.account
    assert @paypal.test?
  end

  def test_compositions
    assert_equal Money.new(50000, 'CAD'), @paypal.amount
  end

  def test_acknowledgement    
    Paypal::Notification.any_instance.stubs(:ssl_post).returns('VERIFIED')
    assert @paypal.acknowledge
    
    Paypal::Notification.any_instance.stubs(:ssl_post).returns('INVALID')
    assert !@paypal.acknowledge
  end

  def test_send_acknowledgement
    Paypal::Notification.any_instance.expects(:ssl_post).with(
      "#{Paypal.service_url}?cmd=_notify-validate",
      http_raw_data,
      { 'Content-Length' => "#{http_raw_data.size}", 'User-Agent' => "Active Merchant -- http://activemerchant.org" }
    ).returns('VERIFIED')
    
    assert @paypal.acknowledge
  end

  def test_payment_successful_status
    notification = Paypal::Notification.new('payment_status=Completed')
    assert_equal 'Completed', notification.status
  end
  
  def test_payment_pending_status
    notification = Paypal::Notification.new('payment_status=Pending')
    assert_equal 'Pending', notification.status
  end
  
  def test_payment_failure_status
    notification = Paypal::Notification.new('payment_status=Failed')
    assert_equal 'Failed', notification.status
  end

  def test_respond_to_acknowledge
    assert @paypal.respond_to?(:acknowledge)
  end

  def test_item_id_mapping
    notification = Paypal::Notification.new('item_number=1')
    assert_equal '1', notification.item_id
  end

  def test_custom_mapped_to_item_id
    notification = Paypal::Notification.new('custom=1')
    assert_equal '1', notification.item_id
  end
  
  def test_nil_notification
    notification = Paypal::Notification.new(nil)
    
    Paypal::Notification.any_instance.stubs(:ssl_post).returns('INVALID')
    assert !@paypal.acknowledge
  end
  
  private

  def http_raw_data
    "mc_gross=500.00&address_status=confirmed&payer_id=EVMXCLDZJV77Q&tax=0.00&address_street=164+Waverley+Street&payment_date=15%3A23%3A54+Apr+15%2C+2005+PDT&payment_status=Completed&address_zip=K2P0V6&first_name=Tobias&mc_fee=15.05&address_country_code=CA&address_name=Tobias+Luetke&notify_version=1.7&custom=&payer_status=unverified&business=tobi%40leetsoft.com&address_country=Canada&address_city=Ottawa&quantity=1&payer_email=tobi%40snowdevil.ca&verify_sign=AEt48rmhLYtkZ9VzOGAtwL7rTGxUAoLNsuf7UewmX7UGvcyC3wfUmzJP&txn_id=6G996328CK404320L&payment_type=instant&last_name=Luetke&address_state=Ontario&receiver_email=tobi%40leetsoft.com&payment_fee=&receiver_id=UQ8PDYXJZQD9Y&txn_type=web_accept&item_name=Store+Purchase&mc_currency=CAD&item_number=&test_ipn=1&payment_gross=&shipping=0.00"
  end  
end
