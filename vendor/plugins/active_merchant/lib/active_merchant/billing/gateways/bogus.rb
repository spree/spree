module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # Bogus Gateway
    class BogusGateway < Gateway
      AUTHORIZATION = '53433'
      
      SUCCESS_MESSAGE = "Bogus Gateway: Forced success"
      FAILURE_MESSAGE = "Bogus Gateway: Forced failure"
      ERROR_MESSAGE = "Bogus Gateway: Use CreditCard number 1 for success, 2 for exception and anything else for error"
      CREDIT_ERROR_MESSAGE = "Bogus Gateway: Use trans_id 1 for success, 2 for exception and anything else for error"
      UNSTORE_ERROR_MESSAGE = "Bogus Gateway: Use trans_id 1 for success, 2 for exception and anything else for error"
      CAPTURE_ERROR_MESSAGE = "Bogus Gateway: Use authorization number 1 for exception, 2 for error and anything else for success"
      VOID_ERROR_MESSAGE = "Bogus Gateway: Use authorization number 1 for exception, 2 for error and anything else for success"
      
      self.supported_countries = ['US']
      self.supported_cardtypes = [:bogus]
      self.homepage_url = 'http://example.com'
      self.display_name = 'Bogus'
      
      def authorize(money, creditcard, options = {})
        case creditcard.number
        when '1'
          Response.new(true, SUCCESS_MESSAGE, {:authorized_amount => money.to_s}, :test => true, :authorization => AUTHORIZATION )
        when '2'
          Response.new(false, FAILURE_MESSAGE, {:authorized_amount => money.to_s, :error => FAILURE_MESSAGE }, :test => true)
        else
          raise Error, ERROR_MESSAGE
        end      
      end
  
      def purchase(money, creditcard, options = {})
        case creditcard.number
        when '1'
          Response.new(true, SUCCESS_MESSAGE, {:paid_amount => money.to_s}, :test => true)
        when '2'
          Response.new(false, FAILURE_MESSAGE, {:paid_amount => money.to_s, :error => FAILURE_MESSAGE },:test => true)
        else
          raise Error, ERROR_MESSAGE
        end
      end
 
      def credit(money, ident, options = {})
        case ident
        when '1'
          raise Error, CREDIT_ERROR_MESSAGE
        when '2'
          Response.new(false, FAILURE_MESSAGE, {:paid_amount => money.to_s, :error => FAILURE_MESSAGE }, :test => true)
        else
          Response.new(true, SUCCESS_MESSAGE, {:paid_amount => money.to_s}, :test => true)
        end
      end
 
      def capture(money, ident, options = {})
        case ident
        when '1'
          raise Error, CAPTURE_ERROR_MESSAGE
        when '2'
          Response.new(false, FAILURE_MESSAGE, {:paid_amount => money.to_s, :error => FAILURE_MESSAGE }, :test => true)
        else
          Response.new(true, SUCCESS_MESSAGE, {:paid_amount => money.to_s}, :test => true)
        end
      end

      def void(ident, options = {})
        case ident
        when '1'
          raise Error, VOID_ERROR_MESSAGE
        when '2'
          Response.new(false, FAILURE_MESSAGE, {:authorization => ident, :error => FAILURE_MESSAGE }, :test => true)
        else
          Response.new(true, SUCCESS_MESSAGE, {:authorization => ident}, :test => true)
        end
      end
      
      def store(creditcard, options = {})
        case creditcard.number
        when '1'
          Response.new(true, SUCCESS_MESSAGE, {:billingid => '1'}, :test => true, :authorization => AUTHORIZATION )
        when '2'
          Response.new(false, FAILURE_MESSAGE, {:billingid => nil, :error => FAILURE_MESSAGE }, :test => true)
        else
          raise Error, ERROR_MESSAGE
        end              
      end
      
      def unstore(identification, options = {})
        case identification
        when '1'
          Response.new(true, SUCCESS_MESSAGE, {}, :test => true)
        when '2'
          Response.new(false, FAILURE_MESSAGE, {:error => FAILURE_MESSAGE },:test => true)
        else
          raise Error, UNSTORE_ERROR_MESSAGE
        end
      end
    end
  end
end
