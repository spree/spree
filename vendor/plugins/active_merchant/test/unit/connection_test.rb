require 'test_helper'

class ConnectionTest < Test::Unit::TestCase

  def setup
    @ok = stub(:code => 200, :message => 'OK', :body => 'success')
    @internal_server_error = stub(:code => 500, :message => 'Internal Server Error', :body => 'failure')
    
    @endpoint   = 'https://example.com/tx.php'
    @connection = ActiveMerchant::Connection.new(@endpoint) 
  end
  
  def test_connection_endpoint_parses_string_to_uri
    assert_equal URI.parse(@endpoint), @connection.endpoint
  end
  
  def test_connection_endpoint_accepts_uri
    endpoint = URI.parse(@endpoint)
    connection = ActiveMerchant::Connection.new(endpoint) 
    assert_equal endpoint, connection.endpoint
  end
  
  def test_connection_endpoint_raises_uri_error
    assert_raises URI::InvalidURIError do
      ActiveMerchant::Connection.new("not a URI")
    end
  end
  
  def test_successful_get_request
    Net::HTTP.any_instance.expects(:get).with('/tx.php', {}).returns(@ok)
    response = @connection.request(:get, nil, {})
    assert_equal 'success', response
  end
  
  def test_successful_post_request
    Net::HTTP.any_instance.expects(:post).with('/tx.php', 'data', ActiveMerchant::Connection::RUBY_184_POST_HEADERS).returns(@ok)
    response = @connection.request(:post, 'data', {})
    assert_equal 'success', response
  end
  
  def test_get_raises_argument_error_if_passed_data
    assert_raise(ArgumentError) do
      @connection.request(:get, 'data', {})
    end
  end
  
  def test_request_raises_when_request_method_not_supported
    assert_raise(ArgumentError) do
      @connection.request(:delete, nil, {})
    end
  end
  
  def test_500_response_during_request_raises_client_error
    Net::HTTP.any_instance.stubs(:post).returns(@internal_server_error)
    assert_raises(ActiveMerchant::ResponseError) do
      @connection.request(:post, '', {})
    end
  end
  
  def test_default_read_timeout
    assert_equal ActiveMerchant::Connection::READ_TIMEOUT, @connection.read_timeout
  end
  
  def test_override_read_timeout
    @connection.read_timeout = 20
    assert_equal 20, @connection.read_timeout
  end
  
  def test_default_open_timeout
    @connection.open_timeout = 20
    assert_equal 20, @connection.open_timeout
  end
  
  def test_default_verify_peer
    assert_equal ActiveMerchant::Connection::VERIFY_PEER, @connection.verify_peer
  end
  
  def test_override_verify_peer
    @connection.verify_peer = false
    assert_equal false, @connection.verify_peer
  end
  
  def test_unrecoverable_exception
    Net::HTTP.any_instance.expects(:post).raises(EOFError)
    
    assert_raises(ActiveMerchant::ConnectionError) do
      @connection.request(:post, '')
    end
  end
  
  def test_failure_then_success_with_recoverable_exception
    Net::HTTP.any_instance.expects(:post).times(2).raises(Errno::ECONNREFUSED).then.returns(@ok)
    
    assert_nothing_raised do
      @connection.request(:post, '')
    end
  end
  
  def test_failure_limit_reached
    Net::HTTP.any_instance.expects(:post).times(ActiveMerchant::Connection::MAX_RETRIES).raises(Errno::ECONNREFUSED)
    
    assert_raises(ActiveMerchant::ConnectionError) do 
      @connection.request(:post, '')
    end
  end
  
  def test_failure_then_success_with_retry_safe_enabled
    Net::HTTP.any_instance.expects(:post).times(2).raises(EOFError).then.returns(@ok)
    
    @connection.retry_safe = true
    
    assert_nothing_raised do
      @connection.request(:post, '')
    end
  end
  
  def test_mixture_of_failures_with_retry_safe_enabled
    Net::HTTP.any_instance.expects(:post).times(3).raises(Errno::ECONNRESET).
                                                   raises(Errno::ECONNREFUSED).
                                                   raises(EOFError)
      
    @connection.retry_safe = true
                                                     
    assert_raises(ActiveMerchant::ConnectionError) do  
      @connection.request(:post, '')
    end
  end
  
end