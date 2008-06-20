require File.dirname(__FILE__) + '/../test_helper'

class SimpleGateway
  include ActiveMerchant::PostsData
end

class MockResponse
  def body
  end
end

class PostsDataTests < Test::Unit::TestCase
  URL = 'http://example.com'
  
  def setup
    @gateway = SimpleGateway.new
  end
  
  def teardown
    SimpleGateway.retry_safe = false
  end
  
  def test_single_successful_post
    Net::HTTP.any_instance.expects(:post).once.returns(MockResponse.new)
    
    assert_nothing_raised do
      @gateway.ssl_post(URL, '') 
    end
  end
  
  def test_multiple_successful_posts
    responses = [ MockResponse.new, MockResponse.new ]
    Net::HTTP.any_instance.expects(:post).times(2).returns(*responses)
    
    assert_nothing_raised do
      @gateway.ssl_post(URL, '')
      @gateway.ssl_post(URL, '') 
    end
  end
  
  def test_unrecoverable_exception
    Net::HTTP.any_instance.expects(:post).raises(EOFError)
    
    assert_raises(ActiveMerchant::ConnectionError) do
      @gateway.ssl_post(URL, '') 
    end
  end
  
  def test_failure_then_success_with_recoverable_exception
    Net::HTTP.any_instance.expects(:post).times(2).raises(Errno::ECONNREFUSED).then.returns(MockResponse.new)
    
    assert_nothing_raised do
      @gateway.ssl_post(URL, '')
    end
  end
  
  def test_failure_limit_reached
    Net::HTTP.any_instance.expects(:post).times(ActiveMerchant::PostsData::MAX_RETRIES).raises(Errno::ECONNREFUSED)
    
    assert_raises(ActiveMerchant::ConnectionError) do 
      @gateway.ssl_post(URL, '')
    end
  end
  
  def test_failure_then_success_with_retry_safe_enabled
    Net::HTTP.any_instance.expects(:post).times(2).raises(EOFError).then.returns(MockResponse.new)
    
    @gateway.retry_safe = true
    
    assert_nothing_raised do
      @gateway.ssl_post(URL, '')
    end
  end
  
  def test_mixture_of_failures_with_retry_safe_enabled
    Net::HTTP.any_instance.expects(:post).times(3).raises(Errno::ECONNRESET).
                                                   raises(Errno::ECONNREFUSED).
                                                   raises(EOFError)
      
    @gateway.retry_safe = true
                                                     
    assert_raises(ActiveMerchant::ConnectionError) do  
      @gateway.ssl_post(URL, '')
    end
  end
end