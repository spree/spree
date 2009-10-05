require 'uri'
require 'net/http'
require 'net/https'
require 'benchmark'

module ActiveMerchant  
  class ConnectionError < ActiveMerchantError # :nodoc:
  end
  
  class RetriableConnectionError < ConnectionError # :nodoc:
  end
  
  class ResponseError < ActiveMerchantError # :nodoc:
    attr_reader :response

    def initialize(response, message = nil)
      @response = response
      @message  = message
    end

    def to_s
      "Failed with #{response.code} #{response.message if response.respond_to?(:message)}"
    end
  end
  
  class Connection
    MAX_RETRIES = 3
    OPEN_TIMEOUT = 60
    READ_TIMEOUT = 60
    VERIFY_PEER = true
    RETRY_SAFE = false
    RUBY_184_POST_HEADERS = { "Content-Type" => "application/x-www-form-urlencoded" }
  
    attr_accessor :endpoint
    attr_accessor :open_timeout
    attr_accessor :read_timeout
    attr_accessor :verify_peer
    attr_accessor :retry_safe
    attr_accessor :pem
    attr_accessor :pem_password
    attr_accessor :wiredump_device
    attr_accessor :logger
    attr_accessor :tag
    
    def initialize(endpoint)
      @endpoint     = endpoint.is_a?(URI) ? endpoint : URI.parse(endpoint)
      @open_timeout = OPEN_TIMEOUT
      @read_timeout = READ_TIMEOUT
      @retry_safe   = RETRY_SAFE
      @verify_peer  = VERIFY_PEER
    end
    
    def request(method, body, headers = {})
      retry_exceptions do 
        begin
          info "#{method.to_s.upcase} #{endpoint}", tag

          result = nil
          
          realtime = Benchmark.realtime do
            result = case method
            when :get
              raise ArgumentError, "GET requests do not support a request body" if body
              http.get(endpoint.request_uri, headers)
            when :post
              debug body
              http.post(endpoint.request_uri, body, RUBY_184_POST_HEADERS.merge(headers))
            else
              raise ArgumentError, "Unsupported request method #{method.to_s.upcase}"
            end
          end
          
          info "--> %d %s (%d %.4fs)" % [result.code, result.message, result.body ? result.body.length : 0, realtime], tag
          response = handle_response(result)
          debug response
          response
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
    
    private
    def http
      http = Net::HTTP.new(endpoint.host, endpoint.port)
      configure_debugging(http)
      configure_timeouts(http)
      configure_ssl(http)
      configure_cert(http)
      http
    end
    
    def configure_debugging(http)
      http.set_debug_output(wiredump_device)
    end
    
    def configure_timeouts(http)
      http.open_timeout = open_timeout
      http.read_timeout = read_timeout
    end
    
    def configure_ssl(http)
      return unless endpoint.scheme == "https"

      http.use_ssl = true
      
      if verify_peer
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER
        http.ca_file     = File.dirname(__FILE__) + '/../../certs/cacert.pem'
      else               
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end
    end
    
    def configure_cert(http)
      return if pem.blank?
      
      http.cert = OpenSSL::X509::Certificate.new(pem)
      
      if pem_password
        http.key = OpenSSL::PKey::RSA.new(pem, pem_password)
      else
        http.key = OpenSSL::PKey::RSA.new(pem)
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
    
    def handle_response(response)
      case response.code.to_i
      when 200...300
        response.body
      else
        raise ResponseError.new(response)
      end
    end
    
    def debug(message, tag = nil)
      log(:debug, message, tag)
    end
    
    def info(message, tag = nil)
      log(:info, message, tag)
    end
    
    def log(level, message, tag)
      message = "[#{tag}] #{message}" if tag
      logger.send(level, message) if logger
    end
  end
end