module ActiveMerchant #:nodoc:
  class ConnectionError < ActiveMerchantError
  end
  
  class RetriableConnectionError < ConnectionError
  end
  
  module PostsData  #:nodoc:
    MAX_RETRIES = 3
    OPEN_TIMEOUT = 60
    READ_TIMEOUT = 60
    
    def self.included(base)
      base.class_inheritable_accessor :ssl_strict
      base.ssl_strict = true
      
      base.class_inheritable_accessor :pem_password
      base.pem_password = false
      
      base.class_inheritable_accessor :retry_safe
      base.retry_safe = false
    end
    
    def ssl_post(url, data, headers = {})
      uri   = URI.parse(url)

      http = Net::HTTP.new(uri.host, uri.port) 
      http.open_timeout = OPEN_TIMEOUT
      http.read_timeout = READ_TIMEOUT
      http.use_ssl      = true
      
      if ssl_strict
        http.verify_mode    = OpenSSL::SSL::VERIFY_PEER
        http.ca_file        = File.dirname(__FILE__) + '/../../certs/cacert.pem'
      else
        http.verify_mode    = OpenSSL::SSL::VERIFY_NONE
      end
      
      if @options && !@options[:pem].blank?
        http.cert           = OpenSSL::X509::Certificate.new(@options[:pem])
        
        if pem_password
          raise ArgumentError, "The private key requires a password" if @options[:pem_password].blank?
          http.key            = OpenSSL::PKey::RSA.new(@options[:pem], @options[:pem_password])
        else
          http.key            = OpenSSL::PKey::RSA.new(@options[:pem])
        end
      end

      retry_exceptions do 
        begin
          http.post(uri.request_uri, data, headers).body
        rescue EOFError => e
          raise ConnectionError, "The remote server dropped the connection"
        rescue Errno::ECONNRESET => e
          raise ConnectionError, "The remote server reset the connection"
        rescue Errno::ECONNREFUSED => e
          raise RetriableConnectionError, "The remote server refused the connection"
        rescue Timeout::Error, Errno::ETIMEDOUT => e
          raise ConnectionError, "The connection to the remote server timed out"
        end
      end
    end    
    
    def retry_exceptions
      retries = MAX_RETRIES
      begin
        yield
      rescue RetriableConnectionError => e
        retries -= 1
        retry unless retries.zero?
        raise ConnectionError, e.message
      rescue ConnectionError
        retries -= 1
        retry if retry_safe && !retries.zero?
        raise
      end
    end
  end
end
