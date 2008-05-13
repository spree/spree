module ActiveMerchant
  module Billing
        
    class PlugnpayGateway < Gateway
      class PlugnpayPostData < PostData
        # Fields that will be sent even if they are blank
        self.required_fields = [ :publisher_name, :publisher_password, 
          :card_amount, :card_name, :card_number, :card_exp, :orderID ]
      end                                                  
                                                           
      URL = 'https://pay1.plugnpay.com/payment/pnpremote.cgi'
                                                        
      CARD_CODE_MESSAGES = {
        "M" => "Card verification number matched",
        "N" => "Card verification number didn't match",
        "P" => "Card verification number was not processed",
        "S" => "Card verification number should be on card but was not indicated",
        "U" => "Issuer was not certified for card verification"
      }

      CARD_CODE_ERRORS = %w( N S )
      
      AVS_MESSAGES = {
        "A" => "Street address matches billing information, zip/postal code does not",
        "B" => "Address information not provided for address verification check",
        "E" => "Address verification service error",
        "G" => "Non-U.S. card-issuing bank",
        "N" => "Neither street address nor zip/postal match billing information",
        "P" => "Address verification not applicable for this transaction",
        "R" => "Payment gateway was unavailable or timed out",
        "S" => "Address verification service not supported by issuer",
        "U" => "Address information is unavailable",
        "W" => "9-digit zip/postal code matches billing information, street address does not",
        "X" => "Street address and 9-digit zip/postal code matches billing information",
        "Y" => "Street address and 5-digit zip/postal code matches billing information",
        "Z" => "5-digit zip/postal code matches billing information, street address does not",
      }
      
      AVS_ERRORS = %w( A E N R W Z )
      
      PAYMENT_GATEWAY_RESPONSES = {
        "P01" => "AVS Mismatch Failure",
        "P02" => "CVV2 Mismatch Failure",
        "P21" => "Transaction may not be marked",
        "P30" => "Test Tran. Bad Card",
        "P35" => "Test Tran. Problem",
        "P40" => "Username already exists",
        "P41" => "Username is blank",
        "P50" => "Fraud Screen Failure",
        "P51" => "Missing PIN Code",
        "P52" => "Invalid Bank Acct. No.",
        "P53" => "Invalid Bank Routing No.",
        "P54" => "Invalid/Missing Check No.",
        "P55" => "Invalid Credit Card No.",
        "P56" => "Invalid CVV2/CVC2 No.",
        "P57" => "Expired. CC Exp. Date",
        "P58" => "Missing Data",
        "P59" => "Missing Email Address",
        "P60" => "Zip Code does not match Billing State.",
        "P61" => "Invalid Billing Zip Code",
        "P62" => "Zip Code does not match Shipping State.",
        "P63" => "Invalid Shipping Zip Code",
        "P64" => "Invalid Credit Card CVV2/CVC2 Format.",
        "P65" => "Maximum number of attempts has been exceeded.",
        "P66" => "Credit Card number has been flagged and can not be used to access this service.",
        "P67" => "IP Address is on Blocked List.",
        "P68" => "Billing country does not match ipaddress country.",
        "P69" => "US based ipaddresses are currently blocked.",
        "P70" => "Credit Cards issued from this bank are currently not being accepted.",
        "P71" => "Credit Cards issued from this bank are currently not being accepted.",
        "P72" => "Daily volume exceeded.",
        "P73" => "Too many transactions within allotted time.",
        "P91" => "Missing/incorrect password",
        "P92" => "Account not configured for mobil administration",
        "P93" => "IP Not registered to username.",
        "P94" => "Mode not permitted for this account.",
        "P95" => "Currently Blank",
        "P96" => "Currently Blank",
        "P97" => "Processor not responding",
        "P98" => "Missing merchant/publisher name",
        "P99" => "Currently Blank"
      }
      
      TRANSACTIONS = {
        :authorization => 'auth',
        :purchase => 'auth',
        :capture => 'mark',
        :void => 'void',
        :refund => 'return',
        :credit => 'newreturn'
      }
     
      SUCCESS_CODES = [ 'pending', 'success' ]
      FAILURE_CODES = [ 'badcard', 'fraud' ]
     
      self.default_currency = 'USD'
      self.supported_countries = ['US']
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]
      self.homepage_url = 'http://www.plugnpay.com/'
      self.display_name = "Plug'n Pay"

      def initialize(options = {})
        requires!(options, :login, :password)
        @options = options
        super
      end
      
      def purchase(money, creditcard, options = {})
        post = PlugnpayPostData.new
        
        add_amount(post, money, options)
        add_creditcard(post, creditcard)
        add_addresses(post, options)
        add_invoice_data(post, options)
        add_customer_data(post, options)
         
        post[:authtype] = 'authpostauth'
        commit(:authorization, post)
      end  
      
      def authorize(money, creditcard, options = {})
        post = PlugnpayPostData.new
        
        add_amount(post, money, options)
        add_creditcard(post, creditcard)        
        add_addresses(post, options)
        add_invoice_data(post, options)        
        add_customer_data(post, options)
        
        post[:authtype] = 'authonly'
        commit(:authorization, post)
      end                  

      def capture(money, authorization, options = {})
        post = PlugnpayPostData.new
        
        post[:orderID] = authorization
        
        add_amount(post, money, options)
        add_customer_data(post, options)
         
        commit(:capture, post)
      end
      
      def void(authorization, options = {})
        post = PlugnpayPostData.new
        
        post[:orderID] = authorization
        post[:txn_type] = 'auth'
        
        commit(:void, post)
      end
      
      def credit(money, identification_or_creditcard, options = {})
        post = PlugnpayPostData.new
        add_amount(post, money, options)
       
        if identification_or_creditcard.is_a?(String)
          post[:orderID] = identification_or_creditcard
          
          commit(:refund, post)
        else
          add_creditcard(post, identification_or_creditcard)        
          add_addresses(post, options)   
          add_customer_data(post, options) 
          
          commit(:credit, post)
        end
      end
      
      private                                 
      def commit(action, post)
        response = parse( ssl_post(URL, post_data(action, post)) )
        
        success = SUCCESS_CODES.include?(response[:finalstatus])
        message = success ? 'Success' : message_from(response)
            
        Response.new(success, message, response, 
          :test => test?, 
          :authorization => response[:orderid],
          :avs_result => { :code => response[:avs_code] },
          :cvv_result => response[:cvvresp]
        )
      end
                                               
      def parse(body)
        body = CGI.unescape(body)
        results = {}
        body.split('&').collect { |e| e.split('=') }.each do |key,value|
          results[key.downcase.to_sym] = normalize(value.to_s.strip)
        end
        
        results.delete(:publisher_password)
        results[:avs_message] = AVS_MESSAGES[results[:avs_code]] if results[:avs_code]
        results[:card_code_message] = CARD_CODE_MESSAGES[results[:cvvresp]] if results[:cvvresp]
        
        results
      end     

      def post_data(action, post)
        post[:mode]               = TRANSACTIONS[action]
        post[:convert]            = 'underscores'
        post[:app_level]          = 0
        post[:publisher_name]     = @options[:login]
        post[:publisher_password] = @options[:password]
      
        post.to_s
      end
      
      def add_creditcard(post, creditcard)      
        post[:card_number]  = creditcard.number
        post[:card_cvv]     = creditcard.verification_value
        post[:card_exp]     = expdate(creditcard)
        post[:card_name]    = creditcard.name.slice(0..38)
      end
      
      def add_customer_data(post, options)
        post[:email] = options[:email]
        post[:dontsndmail]        = 'yes' unless options[:send_email_confirmation]
        post[:ipaddress] = options[:ip]
      end
      
      def add_invoice_data(post, options)
        post[:shipping] = amount(options[:shipping]) unless options[:shipping].blank?
        post[:tax] = amount(options[:tax]) unless options[:tax].blank?  
      end

      def add_addresses(post, options)      
        if address = options[:billing_address] || options[:address]
          post[:card_address1] = address[:address1]
          post[:card_zip]      = address[:zip]     
          post[:card_city]     = address[:city]    
          post[:card_country]  = address[:country]
          post[:phone]         = address[:phone]

          case address[:country]
          when 'US', 'CA'
            post[:card_state] = address[:state]
          else
            post[:card_state] = 'ZZ' 
            post[:card_prov]  = address[:state]
          end
        end
        
        if shipping_address = options[:shipping_address] || address
          post[:shipname] = shipping_address[:name]
          post[:address1] = shipping_address[:address1]
          post[:address2] = shipping_address[:address2]
          post[:city] = shipping_address[:city]
          
          case shipping_address[:country]
          when 'US', 'CA'
            post[:state] = shipping_address[:state]
          else
            post[:state] = 'ZZ' 
            post[:province]  = shipping_address[:state]
          end
          
          post[:country] = shipping_address[:country]
          post[:zip] = shipping_address[:zip]
        end        
      end
      
      def add_amount(post, money, options)
        post[:card_amount] = amount(money)
        post[:currency] = options[:currency] || currency(money)
      end
    
      # Make a ruby type out of the response string
      def normalize(field)
        case field
        when "true"   then true
        when "false"  then false
        when ""       then nil
        when "null"   then nil
        else field
        end        
      end          
      
      def message_from(results)
        PAYMENT_GATEWAY_RESPONSES[results[:resp_code]]
      end
        
      def expdate(creditcard)
        year  = sprintf("%.4i", creditcard.year)
        month = sprintf("%.2i", creditcard.month)

        "#{month}/#{year[-2..-1]}"
      end
    end
  end
end
