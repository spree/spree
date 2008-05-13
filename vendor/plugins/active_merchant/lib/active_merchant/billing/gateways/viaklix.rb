module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class ViaklixGateway < Gateway
      TEST_URL = 'https://demo.viaklix.com/process.asp'
      LIVE_URL = 'https://www.viaklix.com/process.asp'
      
      APPROVED = '0'
      
      self.supported_cardtypes = [:visa, :master, :american_express]
      self.supported_countries = ['US']
      self.display_name = 'ViaKLIX'
      self.homepage_url = 'http://viaklix.com'
      
      # Initialize the Gateway
      #
      # The gateway requires that a valid login and password be passed
      # in the +options+ hash.
      # 
      # ==== Options
      #
      # * <tt>:login</tt> -- Merchant ID
      # * <tt>:password</tt> -- PIN
      # * <tt>:user</tt> -- Specify a subuser of the account (optional)
      # * <tt>:test => +true+ or +false+</tt> -- Force test transactions
      def initialize(options = {})
        requires!(options, :login, :password)
        @options = options
        super
      end
      
      # Make a purchase  
      def purchase(money, creditcard, options = {})
        form = {}
        add_invoice(form, options)
        add_creditcard(form, creditcard)        
        add_address(form, options)   
        add_customer_data(form, options)
        commit('SALE', money, form)
      end
      
      # Make a credit to a card (Void can only be done from the virtual terminal)
      # Viaklix does not support credits by reference. You must pass in the credit card
      def credit(money, creditcard, options = {})
        if creditcard.is_a?(String)
          raise ArgumentError, "Reference credits are not supported. Please supply the original credit card"
        end
        
        form = {}
        add_invoice(form, options)
        add_creditcard(form, creditcard)        
        add_address(form, options)   
        add_customer_data(form, options)
        commit('CREDIT', money, form)
      end
      
      private
      def add_customer_data(form, options)
        form[:email] = options[:email].to_s.slice(0, 100) unless options[:email].blank?
        form[:customer_code] = options[:customer].to_s.slice(0, 17) unless options[:customer].blank?
      end
      
      def add_invoice(form,options)
        form[:invoice_number] = (options[:order_id] || options[:invoice]).to_s.slice(0, 10)
        form[:description] = options[:description].to_s.slice(0, 255)
      end
      
      def add_address(form,options)
        billing_address = options[:billing_address] || options[:address] 
        
        if billing_address
          form[:avs_address]    = billing_address[:address1].to_s.slice(0, 30)
          form[:address2]       = billing_address[:address2].to_s.slice(0, 30)
          form[:avs_zip]        = billing_address[:zip].to_s.slice(0, 10)
          form[:city]           = billing_address[:city].to_s.slice(0, 30)
          form[:state]          = billing_address[:state].to_s.slice(0, 10)
          form[:company]        = billing_address[:company].to_s.slice(0, 50)
          form[:phone]          = billing_address[:phone].to_s.slice(0, 20)
          form[:country]        = billing_address[:country].to_s.slice(0, 50)
        end
                
        if shipping_address = options[:shipping_address]
          first_name, last_name = parse_first_and_last_name(shipping_address[:name])
          form[:ship_to_first_name]     = first_name.to_s.slice(0, 20)
          form[:ship_to_last_name]      = last_name.to_s.slice(0, 30)
          form[:ship_to_address]        = shipping_address[:address1].to_s.slice(0, 30)
          form[:ship_to_city]           = shipping_address[:city].to_s.slice(0, 30)
          form[:ship_to_state]          = shipping_address[:state].to_s.slice(0, 10)
          form[:ship_to_company]        = shipping_address[:company].to_s.slice(0, 50)
          form[:ship_to_country]        = shipping_address[:country].to_s.slice(0, 50)
          form[:ship_to_zip]            = shipping_address[:zip].to_s.slice(0, 10)
        end
      end
      
      def parse_first_and_last_name(value)
        name = value.to_s.split(' ')
        
        last_name = name.pop || ''
        first_name = name.join(' ')
        [ first_name, last_name ] 
      end
      
      def add_creditcard(form, creditcard)
        form[:card_number] = creditcard.number
        form[:exp_date] = expdate(creditcard)
        
        if creditcard.verification_value?
          form[:cvv2cvc2] = creditcard.verification_value 
          form[:cvv2] = 'present'
        end
        
        form[:first_name] = creditcard.first_name.to_s.slice(0, 20)
        form[:last_name] = creditcard.last_name.to_s.slice(0, 30)
      end
      
      def preamble
        result = {
          'merchant_id'   => @options[:login],
          'pin'           => @options[:password],
          'show_form'     => 'false',
          'test_mode'     => @options[:test] ? 'TRUE' : 'FALSE',
          'result_format' => 'ASCII',          
        }
        
        result['user_id'] = @options[:user] unless @options[:user].blank?
        result
      end
      
      def commit(action, money, parameters)
        parameters[:amount] = amount(money)
        parameters[:transaction_type] = action
            
        response = parse( ssl_post(test? ? TEST_URL : LIVE_URL, post_data(parameters)) )

        Response.new(response['result'] == APPROVED, response['result_message'], response, 
          :test => @options[:test] || test?, 
          :authorization => response['txn_id'],
          :avs_result => { :code => response['avs_response'] },
          :cvv_result => response['cvv2_response']
        )
      end
      
      def post_data(parameters)
        result = preamble
        result.merge!(parameters)        
        result.collect { |key, value| "ssl_#{key}=#{CGI.escape(value.to_s)}" }.join("&")
      end
      
      def expdate(creditcard)
        year  = sprintf("%.4i", creditcard.year)
        month = sprintf("%.2i", creditcard.month)
        "#{month}#{year[2..3]}"
      end
      
      # Parse the response message
      def parse(msg)
        resp = {}
        msg.split("\r\n").collect{|li|
            key, value = li.split("=")
            resp[key.gsub(/^ssl_/, '')] = value.to_s.strip
          }
        resp
      end
    end
  end
end