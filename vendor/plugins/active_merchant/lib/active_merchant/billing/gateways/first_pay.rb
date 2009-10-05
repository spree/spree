module ActiveMerchant #:nodoc:
  module Billing #:nodoc:    
    class FirstPayGateway < Gateway
      class FirstPayPostData < PostData
        # Fields that will be sent even if they are blank
        self.required_fields = [ :action, :amount, :trackid ]   
      end

      # both URLs are IP restricted
      TEST_URL = 'https://apgcert.first-pay.com/AcqENGIN/SecureCapture'
      LIVE_URL = 'https://acqengin.first-pay.com/AcqENGIN/SecureCapture'
      
      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = ['US']
      
      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master]
      
      # The homepage URL of the gateway
      self.homepage_url = 'http://www.first-pay.com'
      
      # The name of the gateway
      self.display_name = 'First Pay'
      
      # all transactions are in cents
      self.money_format = :cents
      
      ACTIONS = {
        'sale' => 1,
        'credit' => 2,
        'void' => 3
      }
      
      def initialize(options = {})
        requires!(options, :login, :password)
        @options = options
        super
      end  
      
      def purchase(money, creditcard, options = {})
        post = FirstPayPostData.new
        add_invoice(post, options)
        add_creditcard(post, creditcard)
        add_address(post, options)
        add_customer_data(post, options)
        
        commit('sale', money, post)
      end                       
      
      def credit(money, reference, options = {})
        raise ArgumentError, "Both TransactionID and CreditCard are required" unless reference.is_a?(String) && options[:credit_card]

        post = FirstPayPostData.new
        add_invoice(post, options)
        add_creditcard(post, options[:credit_card])
        add_address(post, options)
        add_customer_data(post, options)
        add_credit_data(post, reference)
      
        commit('credit', money, post)
      end
      
      def void(money, creditcard, options = {})
        post = FirstPayPostData.new
        add_creditcard(post, creditcard)
        add_void_data(post, options)
        add_invoice(post, options)
        add_customer_data(post, options)
        
        commit('void', money, post)
      end
      
      
      private
      
      def add_customer_data(post, options)
        post[:cardip] = options[:ip]
        post[:email] = options[:email]
      end
      
      def add_address(post, options)
        if billing_address = options[:billing_address] || options[:address]
          post[:addr]     = billing_address[:address1].to_s + ' ' + billing_address[:address2].to_s
          post[:city]     = billing_address[:city]
          post[:state]    = billing_address[:state]
          post[:zip]      = billing_address[:zip]                             
          post[:country]  = billing_address[:country]
        end
      end
      
      def add_invoice(post, options)
        post[:trackid] = rand(Time.now)
      end
      
      def add_creditcard(post, creditcard)
        post[:member] = creditcard.first_name.to_s + " " + creditcard.last_name.to_s
        post[:card] = creditcard.number
        post[:exp] = expdate(creditcard)
      end
      
      def expdate(credit_card)
        year  = sprintf("%.4i", credit_card.year)
        month = sprintf("%.2i", credit_card.month)

        "#{month}#{year[-2..-1]}"
      end
      
      def add_credit_data(post, transaction_id)
        post[:transid] = transaction_id
      end
      
      def add_void_data(post, options)
        post[:transid] = options[:transactionid]
      end
      
      def commit(action, money, post)
        response = parse( ssl_post(test? ? TEST_URL : LIVE_URL, post_data(action, post, money)) )
                
        Response.new(response[:response] == 'CAPTURED', response[:message], response,
          :test => test?,
          :authorization => response[:authorization],
          :avs_result => { :code => response[:avsresponse] },
          :cvv_result => response[:cvvresponse])
      end
      
      def parse(body)
        response = {}
        
        # check for an error first
        if body.include?('!ERROR!')
          response[:response] = 'ERROR'
          response[:message] = error_message_from(body)
        else
          # a capture / not captured response will be : delimited
          split = body.split(':')
          response[:response] = split[0]
          
          # FirstPay docs are worthless. turns out the transactionid is required for credits
          # so we need to store that in authorization, not the actual auth.
          if response[:response] == 'CAPTURED'
            response[:message] = 'CAPTURED'
            response[:authorization] = split[9] # actually the transactionid
            response[:auth] = split[1]
            response[:avsresponse] = split[3]
            response[:cvvresponse] = split[17]
          else
            # NOT CAPTURED response
            response[:message] = split[1]
            response[:transactionid] = split[9]
          end
        end
        
        return response
      end
      
      def error_message_from(response)
        # error messages use this format - '!ERROR! 704-MISSING BASIC DATA TYPE:card, exp, zip, addr, member, amount\n'
        response.split("! ")[1].chomp
      end
      
      def post_data(action, post, money)
        post[:vid]        = @options[:login]  
        post[:password]   = @options[:password]
        post[:action]     = ACTIONS[action]
        post[:amount]     = amount(money)
        
        return post.to_post_data
      end
    end
  end
end

