module ActiveMerchant #:nodoc:
  module PostsData  #:nodoc:

    def self.included(base)
      base.superclass_delegating_accessor :ssl_strict
      base.ssl_strict = true
      
      base.class_inheritable_accessor :retry_safe
      base.retry_safe = false

      base.superclass_delegating_accessor :open_timeout
      base.open_timeout = 60

      base.superclass_delegating_accessor :read_timeout
      base.read_timeout = 60
      
      base.superclass_delegating_accessor :logger
      base.superclass_delegating_accessor :wiredump_device
    end
    
    def ssl_get(endpoint, headers={})
      ssl_request(:get, endpoint, nil, headers)
    end
    
    def ssl_post(endpoint, data, headers = {})
      ssl_request(:post, endpoint, data, headers)
    end
    
    def http_get(endpoint, headers={})
      http_request(:get, endpoint, nil, headers)
    end
    
    def http_post(endpoint, data, headers = {})
      http_request(:post, endpoint, data, headers)
    end    
    
    private
    def ssl_request(method, endpoint, data, headers = {})
      connection = Connection.new(endpoint)
      connection.open_timeout = open_timeout
      connection.read_timeout = read_timeout
      connection.retry_safe   = retry_safe
      connection.verify_peer  = ssl_strict
      connection.logger       = logger
      connection.tag          = self.class.name
      connection.wiredump_device = wiredump_device
      
      connection.pem          = @options[:pem] if @options
      connection.pem_password = @options[:pem_password] if @options
      
      connection.request(method, data, headers)
    end

    def http_request(method, endpoint, data, headers = {})
      connection = Connection.new(endpoint)
      connection.open_timeout = open_timeout
      connection.read_timeout = read_timeout
      connection.retry_safe   = false
      connection.verify_peer  = false
      connection.logger       = logger
      connection.tag          = self.class.name
      connection.wiredump_device = wiredump_device
      
      connection.pem          = nil
      connection.pem_password = nil
      
      connection.request(method, data, headers)
    end
    
  end
end
