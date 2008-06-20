require File.dirname(__FILE__) + '/../../../test_helper'

class ChronopayNotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations
  
  def setup
    @notification = Chronopay::Notification.new(http_raw_data)
  end
  
  def test_notification
    assert_instance_of Chronopay::Notification, @notification
  end

  def test_accessors
    assert @notification.complete?
    assert_equal "Completed", @notification.status
    assert_equal "003176-000000005", @notification.customer_id
    assert_equal "003176-0001", @notification.site_id
    assert_equal "003176-0001-0001", @notification.product_id
    assert_equal "CODY FAUSER", @notification.name
    assert_equal 'XX', @notification.state
    assert_equal 'Ottawa', @notification.city
    assert_equal '138 Clarence St.', @notification.street
    assert_equal 'CAD', @notification.currency
    assert_equal 'first', @notification.item_id
    assert_equal 'second', @notification.custom2
    assert_equal 'third', @notification.custom3

    # If the date and time are nil then it is a test notification
    assert @notification.test?
  end
  
  # docs
  def test_parse_received_at
    # mm/dd/yyyy format
    raw_received = "date=03%2f30%2f2006&time=12%3a30%3a10"
    @notification = Chronopay::Notification.new(raw_received)
    assert_equal CGI.unescape("03%2f30%2f2006"), @notification.params['date']
    assert_equal CGI.unescape("12%3a30%3a10"), @notification.params['time']
    assert_equal Time.local(2006, 3, 30, 12, 30, 10), @notification.received_at
  end

  def test_compositions
    assert_equal Money.new(50000, 'CAD'), @notification.amount
  end

  def test_payment_successful_status
    notification = Chronopay::Notification.new('transaction_type=onetime')
    assert_equal 'Completed', notification.status
  end
  
  def test_payment_failure_status
    notification = Chronopay::Notification.new('transaction_type=decline')
    assert_equal 'Failed', notification.status
  end

  def test_acknowledge
    assert @notification.acknowledge
  end
  
  private
  def http_raw_data
    "transaction_type=onetime&customer_id=003176-000000005&site_id=003176-0001&product_id=003176-0001-0001&date=&time=&transaction_id=&email=codyfauser%40gmail.com&country=CAN&name=CODY+FAUSER&city=Ottawa&street=138+Clarence+St.&phone=&state=XX&zip=K1N+5P8&language=EN&cs1=first&cs2=second&cs3=third&username=&password=&total=500.00&currency=CAD"
  end  
end

