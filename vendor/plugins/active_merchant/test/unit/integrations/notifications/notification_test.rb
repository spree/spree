require 'test_helper'

class NotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @notification = Notification.new(http_raw_data)
  end

  def test_raw
    assert_equal http_raw_data, @notification.raw
  end

  def test_parse
    assert_equal "500.00", @notification.params['mc_gross']
    assert_equal "confirmed", @notification.params['address_status']
    assert_equal "EVMXCLDZJV77Q", @notification.params['payer_id']
    assert_equal "Completed", @notification.params['payment_status']    
    assert_equal CGI.unescape("15%3A23%3A54+Apr+15%2C+2005+PDT"), @notification.params['payment_date']
  end

  def test_accessors
    assert_raise(NotImplementedError){ @notification.status }
    assert_raise(NotImplementedError){ @notification.gross }
    assert_raise(NotImplementedError){ @notification.gross_cents }
  end
  
  def test_notification_data_with_period
    notification = Notification.new(http_raw_data_with_period)
    assert_equal 'clicked', notification.params['checkout.x']
  end

  def test_valid_sender_always_true_in_testmode
    assert_equal ActiveMerchant::Billing::Base.integration_mode, :test
    assert @notification.valid_sender?(nil)
    assert @notification.valid_sender?('localhost')
  end

  def test_valid_sender_always_true_when_no_ips
    ActiveMerchant::Billing::Base.integration_mode = :production
    assert @notification.valid_sender?(nil)
    assert @notification.valid_sender?('localhost')
    ActiveMerchant::Billing::Base.integration_mode = :test
  end
  
  private
  def http_raw_data
    "mc_gross=500.00&address_status=confirmed&payer_id=EVMXCLDZJV77Q&tax=0.00&address_street=164+Waverley+Street&payment_date=15%3A23%3A54+Apr+15%2C+2005+PDT&payment_status=Completed&address_zip=K2P0V6&first_name=Tobias&mc_fee=15.05&address_country_code=CA&address_name=Tobias+Luetke&notify_version=1.7&custom=&payer_status=unverified&business=tobi%40leetsoft.com&address_country=Canada&address_city=Ottawa&quantity=1&payer_email=tobi%40snowdevil.ca&verify_sign=AEt48rmhLYtkZ9VzOGAtwL7rTGxUAoLNsuf7UewmX7UGvcyC3wfUmzJP&txn_id=6G996328CK404320L&payment_type=instant&last_name=Luetke&address_state=Ontario&receiver_email=tobi%40leetsoft.com&payment_fee=&receiver_id=UQ8PDYXJZQD9Y&txn_type=web_accept&item_name=Store+Purchase&mc_currency=CAD&item_number=&test_ipn=1&payment_gross=&shipping=0.00"
  end
  
  def http_raw_data_with_period
    "mc_gross=500.00&address_status=confirmed&payer_id=EVMXCLDZJV77Q&tax=0.00&address_street=164+Waverley+Street&payment_date=15%3A23%3A54+Apr+15%2C+2005+PDT&payment_status=Completed&address_zip=K2P0V6&first_name=Tobias&mc_fee=15.05&address_country_code=CA&address_name=Tobias+Luetke&notify_version=1.7&custom=&payer_status=unverified&business=tobi%40leetsoft.com&address_country=Canada&address_city=Ottawa&quantity=1&payer_email=tobi%40snowdevil.ca&verify_sign=AEt48rmhLYtkZ9VzOGAtwL7rTGxUAoLNsuf7UewmX7UGvcyC3wfUmzJP&txn_id=6G996328CK404320L&payment_type=instant&last_name=Luetke&address_state=Ontario&receiver_email=tobi%40leetsoft.com&payment_fee=&receiver_id=UQ8PDYXJZQD9Y&txn_type=web_accept&item_name=Store+Purchase&mc_currency=CAD&item_number=&test_ipn=1&payment_gross=&shipping=0.00&checkout.x=clicked"
  end
end
