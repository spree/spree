require File.dirname(__FILE__) + '/../../../test_helper'

class TwoCheckoutNotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @test_notification = TwoCheckout::Notification.new(test_http_raw_data)
    @live_notification = TwoCheckout::Notification.new(live_http_raw_data)
  end

  def test_accessors
    assert @test_notification.complete?
    assert @test_notification.test?
    assert_equal "Completed", @test_notification.status
    
    assert_equal "3644445821", @test_notification.transaction_id
    assert_equal "10", @test_notification.item_id
    assert_equal "31.66", @test_notification.gross
    assert_equal "USD", @test_notification.currency
    assert_equal 'cody@example.com', @test_notification.payer_email
  end
  
  def test_live_accessors
    assert @live_notification.complete?
    assert !@live_notification.test?
  end

  def test_compositions
    assert_equal Money.new(3166, 'USD'), @test_notification.amount
  end

  def test_acknowledgement
    assert @test_notification.acknowledge
  end
  
  def test_verififcation_of_test_notification
    assert !@test_notification.verify('tango')
    @test_notification
    
    
    assert @live_notification.verify('tango')
    
    order = @test_notification.params['order_number']
    
  end
  
  private
  def test_http_raw_data
    "sid=1232919&fixed=Y&key=B5446FF1061F5522C29CCCA0F95EA375&state=ON&email=cody%40example.com&city=Ottawa&street_address=1+-+8+Clarence+St%2C+Apartment+5&product_id=&cart_order_id=10&tcoid=8032992fe053170efb7e58de35b07d39&country=Canada&order_number=3644445821&merchant_order_id=%231010&option-=&cart_id=10&Product_description=&lang=&demo=Y&pay_method=CC&quantity=1&total=31.66&phone=(555)555-5555&return_url=&credit_card_processed=Y&zip=K1M+3G7&merchant_product_id=10&card_holder_name=Cody+Fauser"
  end
  
  def live_http_raw_data
    "sid=1232919&fixed=Y&key=0ee5cd112a9d34952167399c6b55d14f&state=ON&email=cody%40example.com&city=Ottawa&street_address=1+-+8+Clarence+St%2C+Apartment+5&product_id=&cart_order_id=10&tcoid=8032992fe053170efb7e58de35b07d39&country=Canada&order_number=3644445821&merchant_order_id=%231010&option-=&cart_id=10&Product_description=&lang=&pay_method=CC&quantity=1&total=31.66&phone=(555)555-5555&return_url=&credit_card_processed=Y&zip=K1M+3G7&merchant_product_id=10&card_holder_name=Cody+Fauser"
  end
end
