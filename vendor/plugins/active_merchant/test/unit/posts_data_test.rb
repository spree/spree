require 'test_helper'

class PostsDataTests < Test::Unit::TestCase

  def setup
    @url = 'http://example.com'
    @gateway = SimpleTestGateway.new
  end
  
  def teardown
    SimpleTestGateway.retry_safe = false
  end
  
  def test_single_successful_post
    ActiveMerchant::Connection.any_instance.expects(:request).returns('')
    
    assert_nothing_raised do
      @gateway.ssl_post(@url, '') 
    end
  end
  
  def test_multiple_successful_posts
    ActiveMerchant::Connection.any_instance.expects(:request).times(2).returns('', '')
    
    assert_nothing_raised do
      @gateway.ssl_post(@url, '')
      @gateway.ssl_post(@url, '') 
    end
  end
    
  def test_setting_ssl_strict_outside_class_definition
    assert_equal SimpleTestGateway.ssl_strict, SubclassGateway.ssl_strict
    SimpleTestGateway.ssl_strict = !SimpleTestGateway.ssl_strict
    assert_equal SimpleTestGateway.ssl_strict, SubclassGateway.ssl_strict
  end

  def test_setting_timeouts
    @gateway.class.open_timeout = 50
    @gateway.class.read_timeout = 37
    ActiveMerchant::Connection.any_instance.expects(:request).returns('')
    ActiveMerchant::Connection.any_instance.expects(:open_timeout=).with(50)
    ActiveMerchant::Connection.any_instance.expects(:read_timeout=).with(37)

    assert_nothing_raised do
      @gateway.ssl_post(@url, '')
    end
  end
end