require 'rexml/document'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class VerifiGateway < Gateway 
      class VerifiPostData < PostData
        # Fields that will be sent even if they are blank
        self.required_fields = [ :amount, :type, :ccnumber, :ccexp, :firstname, :lastname,
          :company, :address1, :address2, :city, :state, :zip, :country, :phone ]   
      end

      URL = 'https://secure.verifi.com/gw/api/transact.php'
            
      RESPONSE_CODE_MESSAGES = {
        "100" => "Transaction was Approved", 
        "200" => "Transaction was Declined by Processor", 
        "201" => "Do Not Honor", 
        "202" => "Insufficient Funds", 
        "203" => "Over Limit", 
        "204" => "Transaction not allowed", 
        "220" => "Incorrect payment Data", 
        "221" => "No Such Card Issuer", 
        "222" => "No Card Number on file with Issuer", 
        "223" => "Expired Card", 
        "224" => "Invalid Expiration Date", 
        "225" => "Invalid Card Security Code", 
        "240" => "Call Issuer for Further Information", 
        "250" => "Pick Up Card", 
        "251" => "Lost Card", 
        "252" => "Stolen Card", 
        "253" => "Fraudulent Card", 
        "260" => "Declined With further Instructions Available (see response text)", 
        "261" => "Declined - Stop All Recurring Payments", 
        "262" => "Declined - Stop this Recurring Program", 
        "263" => "Declined - Update Cardholder Data Available", 
        "264" => "Declined - Retry in a few days", 
        "300" => "Transaction was Rejected by Gateway", 
        "400" => "Transaction Error Returned by Processor", 
        "410" => "Invalid Merchant Configuration", 
        "411" => "Merchant Account is Inactive", 
        "420" => "Communication Error", 
        "421" => "Communication Error with Issuer", 
        "430" => "Duplicate Transaction at Processor", 
        "440" => "Processor Format Error", 
        "441" => "Invalid Transaction Information", 
        "460" => "Processor Feature Not Available", 
        "461" => "Unsupported Card Type"
      }
      
      SUCCESS = 1
      
      TRANSACTIONS = {
        :authorization => 'auth',
        :purchase => 'sale',
        :capture => 'capture',
        :void => 'void',
        :credit => 'credit',
        :refund => 'refund'
      }
      
      self.supported_countries = ['US']
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]
      self.homepage_url = 'http://www.verifi.com/'
      self.display_name = 'Verifi'

    	def initialize(options = {})
        requires!(options, :login, :password)
        @options = options
        super
    	end

      def purchase(money, credit_card, options = {})
        sale_authorization_or_credit_template(:purchase, money, credit_card, options)
      end

      def authorize(money, credit_card, options = {})
        sale_authorization_or_credit_template(:authorization, money, credit_card, options)
      end
                       
      def capture(money, authorization, options = {})
        capture_void_or_refund_template(:capture, money, authorization, options)
      end
      
      def void(authorization, options = {})
        capture_void_or_refund_template(:void, 0, authorization, options)
      end
      
      def credit(money, credit_card_or_authorization, options = {})
        if credit_card_or_authorization.is_a?(String)
          capture_void_or_refund_template(:refund, money, credit_card_or_authorization, options)
        else
          sale_authorization_or_credit_template(:credit, money, credit_card_or_authorization, options)
        end
      end

      private  
             
      def sale_authorization_or_credit_template(trx_type, money, credit_card, options = {})
        post = VerifiPostData.new
        add_security_key_data(post, options, money)
        add_credit_card(post, credit_card)
        add_addresses(post, options)
        add_customer_data(post, options)
        add_invoice_data(post, options)
        add_optional_data(post, options)
        commit(trx_type, money, post)  
      end

      def capture_void_or_refund_template(trx_type, money, authorization, options)
        post = VerifiPostData.new
        post[:transactionid] = authorization
        
        commit(trx_type, money, post)
      end
                    
      def add_credit_card(post, credit_card)
        post[:ccnumber]  = credit_card.number
        post[:ccexp]     = expdate(credit_card)
        post[:firstname] = credit_card.first_name
        post[:lastname]  = credit_card.last_name      
        post[:cvv]       = credit_card.verification_value
      end      
                 
      def expdate(credit_card)
        year  = sprintf("%.4i", credit_card.year)
        month = sprintf("%.2i", credit_card.month)

        "#{month}#{year[-2..-1]}"
      end

      def add_addresses(post, options)
        if billing_address = options[:billing_address] || options[:address]
          post[:company]    = billing_address[:company]
          post[:address1]   = billing_address[:address1]
          post[:address2]   = billing_address[:address2]
          post[:city]       = billing_address[:city]                           
          post[:state]      = billing_address[:state]
          post[:zip]        = billing_address[:zip]                               
          post[:country]    = billing_address[:country]
          post[:phone]      = billing_address[:phone]
          post[:fax]        = billing_address[:fax]             
        end
        
        if shipping_address = options[:shipping_address]
          post[:shipping_firstname] = shipping_address[:first_name]
          post[:shipping_lastname]  = shipping_address[:last_name]  
          post[:shipping_company]   = shipping_address[:company]    
          post[:shipping_address1]  = shipping_address[:address1]   
          post[:shipping_address2]  = shipping_address[:address2]   
          post[:shipping_city]      = shipping_address[:city]       
          post[:shipping_state]     = shipping_address[:state]      
          post[:shipping_zip]       = shipping_address[:zip]        
          post[:shipping_country]   = shipping_address[:country]    
          post[:shipping_email]     = shipping_address[:email]      
        end        
      end
             
      def add_customer_data(post, options)
        post[:email]     = options[:email]
        post[:ipaddress] = options[:ip]
      end
      
      def add_invoice_data(post, options)
        post[:orderid]            = options[:order_id]
        post[:ponumber]           = options[:invoice]
        post[:orderdescription]   = options[:description]
        post[:tax]                = options[:tax]
        post[:shipping]           = options[:shipping]
      end
      
      def add_optional_data(post, options)
        post[:billing_method]     = options[:billing_method]    
        post[:website]            = options[:website]   
        post[:descriptor]         = options[:descriptor]         
        post[:descriptor_phone]   = options[:descriptor_phone]   
        post[:cardholder_auth]    = options[:cardholder_auth]    
        post[:cavv]               = options[:cavv]               
        post[:xid]                = options[:xid]                
        post[:customer_receipt]   = options[:customer_receipt]
      end
                       
      def add_security_key_data(post, options, money)
        # MD5(username|password|orderid|amount|time)
        now = Time.now.to_i.to_s
        md5 = Digest::MD5.new
        md5 << @options[:login].to_s + "|"
        md5 << @options[:password].to_s + "|"
        md5 << options[:order_id].to_s + "|"
        md5 << amount(money).to_s + "|"
        md5 << now
        post[:key]  = md5.hexdigest
        post[:time] = now
      end                  
                                                    
      def commit(trx_type, money, post)
        post[:amount] = amount(money)
        
        response = parse( ssl_post(URL, post_data(trx_type, post)) )
                         
        Response.new(response[:response].to_i == SUCCESS, message_from(response), response,
          :test => test?,
          :authorization => response[:transactionid],
          :avs_result => { :code => response[:avsresponse] },
          :cvv_result => response[:cvvresponse]
        )
      end
      
      def message_from(response)
        response[:response_code_message] ? response[:response_code_message] : ""
      end
                                                      
      def parse(body)
        results = {}
        CGI.parse(body).each { |key, value| results[key.intern] = value[0] }
        results[:response_code_message] = RESPONSE_CODE_MESSAGES[results[:response_code]] if results[:response_code]
        results
      end   
      
      def post_data(trx_type, post)
        post[:username]   = @options[:login]  
        post[:password]   = @options[:password]
        post[:type]       = TRANSACTIONS[trx_type]
        
        post.to_s
      end
    end 
  end
end
