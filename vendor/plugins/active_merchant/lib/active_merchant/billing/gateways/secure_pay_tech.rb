module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class SecurePayTechGateway < Gateway
      class SecurePayTechPostData < PostData
        self.required_fields = [ :OrderReference, :CardNumber, :CardExpiry, :CardHolderName, :CardType, :MerchantID, :MerchantKey, :Amount, :Currency ]
      end

      URL = 'https://tx.securepaytech.com/web/HttpPostPurchase'

      PAYMENT_GATEWAY_RESPONSES = {
        1 => "Transaction OK",
        2 => "Insufficient funds",
        3 => "Card expired",
        4 => "Card declined",
        5 => "Server error",
        6 => "Communications error",
        7 => "Unsupported transaction type",
        8 => "Bad or malformed request",
        9 => "Invalid card number"
      }
  
      self.default_currency = 'NZD'
      self.supported_countries = ['NZ']
      self.supported_cardtypes = [:visa, :master, :american_express, :diners_club]
      self.homepage_url = 'http://www.securepaytech.com/'
      self.display_name = 'SecurePayTech'

      def initialize(options = {})
        requires!(options, :login, :password)
        @options = options
        super
      end  
      
      def purchase(money, creditcard, options = {})
        post = SecurePayTechPostData.new

        add_invoice(post, money, options)
        add_creditcard(post, creditcard)        
             
        commit(:purchase, post)
      end                       
    
      private                       
      
      def add_invoice(post, money, options)
        post[:Amount] = amount(money)
        post[:Currency] = options[:currency] || currency(money)

        post[:OrderReference] = options[:order_id]
      end
      
      def add_creditcard(post, creditcard)
        post[:CardNumber] = creditcard.number
        post[:CardExpiry] = expdate(creditcard)
        post[:CardHolderName] = creditcard.name
        
        if creditcard.verification_value?
          post[:EnableCSC] = 1
          post[:CSC] = creditcard.verification_value
        end

        # SPT will autodetect this
        post[:CardType] = 0
      end
      
      def parse(body)
        response = CGI.unescape(body).split(',')

        result = {}
        result[:result_code] = response[0].to_i

        if response.length == 2
          result[:fail_reason] = response[1]
        else
          result[:merchant_transaction_reference] = response[1]
          result[:receipt_number] = response[2]
          result[:transaction_number] = response[3]
          result[:authorisation_id] = response[4]
          result[:batch_number] = response[5]
        end

        result
      end    
      
      def commit(action, post)
        response = parse( ssl_post(URL, post_data(action, post) ) )

        Response.new(response[:result_code] == 1, message_from(response), response, 
          :test => test?, 
          :authorization => response[:merchant_transaction_reference]
        )
      end

      def message_from(result)
        PAYMENT_GATEWAY_RESPONSES[result[:result_code]]
      end
      
      def post_data(action, post)
        post[:MerchantID] = @options[:login]
        post[:MerchantKey] = @options[:password]
        post.to_s
      end

      def expdate(creditcard)
        year = sprintf("%.4i", creditcard.year)
        month = sprintf("%.2i", creditcard.month)

        "#{month}#{year[-2..-1]}"
      end
    end
  end
end

