module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module BeanstreamCore
      URL = 'https://www.beanstream.com/scripts/process_transaction.asp'

      TRANSACTIONS = {
        :authorization  => 'PA',
        :purchase       => 'P',
        :capture        => 'PAC',
        :credit         => 'R',
        :void           => 'VP',
        :check_purchase => 'D',
        :check_credit   => 'C',
        :void_purchase  => 'VP',
        :void_credit    => 'VR'
      }

      CVD_CODES = {
        '1' => 'M',
        '2' => 'N',
        '3' => 'I',
        '4' => 'S',
        '5' => 'U',
        '6' => 'P'
      }

      AVS_CODES = {
        '0' => 'R',
        '5' => 'I',
        '9' => 'I'
      }
      
      def self.included(base)
        base.default_currency = 'CAD'

        # The countries the gateway supports merchants from as 2 digit ISO country codes
        base.supported_countries = ['CA']

        # The card types supported by the payment gateway
        base.supported_cardtypes = [:visa, :master, :american_express]

        # The homepage URL of the gateway
        base.homepage_url = 'http://www.beanstream.com/'

        # The name of the gateway
        base.display_name = 'Beanstream.com'
      end
      
      # Only <tt>:login</tt> is required by default, 
      # which is the merchant's merchant ID. If you'd like to perform void, 
      # capture or credit transactions then you'll also need to add a username
      # and password to your account under administration -> account settings ->
      # order settings -> Use username/password validation
      def initialize(options = {})
        requires!(options, :login)
        @options = options
        super
      end
      
      def capture(money, authorization, options = {})
        reference, amount, type = split_auth(authorization)
        
        post = {}
        add_amount(post, money)
        add_reference(post, reference)
        add_transaction_type(post, :capture)
        commit(post)
      end
      
      def credit(money, source, options = {})
        post = {}
        reference, amount, type = split_auth(source)
        add_reference(post, reference)
        add_transaction_type(post, credit_action(type))
        add_amount(post, money)
        commit(post)
      end
    
      private
      def purchase_action(source)
        source.type.to_s == "check" ? :check_purchase : :purchase
      end
      
      def void_action(original_transaction_type)
        original_transaction_type == TRANSACTIONS[:credit] ? :void_credit : :void_purchase
      end
      
      def credit_action(type)
        type == TRANSACTIONS[:check_purchase] ? :check_credit : :credit
      end
      
      def split_auth(string)
        string.split(";")
      end
      
      def add_amount(post, money)
        post[:trnAmount] = amount(money)
      end
      
      def add_original_amount(post, amount)
        post[:trnAmount] = amount
      end

      def add_reference(post, reference)                
        post[:adjId] = reference
      end
      
      def add_address(post, options)      
        if billing_address = options[:billing_address] || options[:address]
          post[:ordName]          = billing_address[:name]
          post[:ordEmailAddress]  = options[:email]
          post[:ordPhoneNumber]   = billing_address[:phone]
          post[:ordAddress1]      = billing_address[:address1]
          post[:ordAddress2]      = billing_address[:address2]
          post[:ordCity]          = billing_address[:city]
          post[:ordProvince]      = billing_address[:state]
          post[:ordPostalCode]    = billing_address[:zip]
          post[:ordCountry]       = billing_address[:country]
        end
        if shipping_address = options[:shipping_address]
          post[:shipName]         = shipping_address[:name]
          post[:shipEmailAddress] = options[:email]
          post[:shipPhoneNumber]  = shipping_address[:phone]
          post[:shipAddress1]     = shipping_address[:address1]
          post[:shipAddress2]     = shipping_address[:address2]
          post[:shipCity]         = shipping_address[:city]
          post[:shipProvince]     = shipping_address[:state]
          post[:shipPostalCode]   = shipping_address[:zip]
          post[:shipCountry]      = shipping_address[:country]
          post[:shippingMethod]   = shipping_address[:shipping_method]
          post[:deliveryEstimate] = shipping_address[:delivery_estimate]
        end
      end

      def add_invoice(post, options)
        post[:trnOrderNumber]   = options[:order_id]
        post[:trnComments]      = options[:description]
        post[:ordItemPrice]     = amount(options[:subtotal])
        post[:ordShippingPrice] = amount(options[:shipping])
        post[:ordTax1Price]     = amount(options[:tax1] || options[:tax])
        post[:ordTax2Price]     = amount(options[:tax2])
        post[:ref1]             = options[:custom]
      end
      
      def add_credit_card(post, credit_card)
        post[:trnCardOwner] = credit_card.name
        post[:trnCardNumber] = credit_card.number
        post[:trnExpMonth] = format(credit_card.month, :two_digits)
        post[:trnExpYear] = format(credit_card.year, :two_digits)
        post[:trnCardCvd] = credit_card.verification_value
      end
            
      def add_check(post, check)
        # The institution number of the consumer’s financial institution. Required for Canadian dollar EFT transactions.
        post[:institutionNumber] = check.institution_number
        
        # The bank transit number of the consumer’s bank account. Required for Canadian dollar EFT transactions.
        post[:transitNumber] = check.transit_number
        
        # The routing number of the consumer’s bank account.  Required for US dollar EFT transactions.
        post[:routingNumber] = check.routing_number
        
        # The account number of the consumer’s bank account.  Required for both Canadian and US dollar EFT transactions.
        post[:accountNumber] = check.account_number
      end
      
      def parse(body)
        results = {}
        if !body.nil?
          body.split(/&/).each do |pair|
            key,val = pair.split(/=/)
            results[key.to_sym] = val.nil? ? nil : CGI.unescape(val)
          end
        end
        
        # Clean up the message text if there is any
        if results[:messageText]
          results[:messageText].gsub!(/<LI>/, "")
          results[:messageText].gsub!(/(\.)?<br>/, ". ")
          results[:messageText].strip!
        end
        
        results
      end
      
      def commit(params)
        post(post_data(params))
      end
      
      def post(data)
        response = parse(ssl_post(URL, data))
        build_response(success?(response), message_from(response), response,
          :test => test? || response[:authCode] == "TEST",
          :authorization => authorization_from(response),
          :cvv_result => CVD_CODES[response[:cvdId]],
          :avs_result => { :code => (AVS_CODES.include? response[:avsId]) ? AVS_CODES[response[:avsId]] : response[:avsId] }
        )
      end
            
      def authorization_from(response)
        "#{response[:trnId]};#{response[:trnAmount]};#{response[:trnType]}"
      end

      def message_from(response)
        response[:messageText]
      end

      def success?(response)
        response[:responseType] == 'R' || response[:trnApproved] == '1'
      end
      
      def add_source(post, source)
        source.type == "check" ? add_check(post, source) : add_credit_card(post, source)
      end
      
      def add_transaction_type(post, action)
        post[:trnType] = TRANSACTIONS[action]
      end
          
      def post_data(params)
        params[:requestType] = 'BACKEND'
        params[:merchant_id] = @options[:login]
        params[:username] = @options[:user] if @options[:user]
        params[:password] = @options[:password] if @options[:password]
        params[:vbvEnabled] = '0'
        params[:scEnabled] = '0'
        
        params.reject{|k, v| v.blank?}.collect { |key, value| "#{key}=#{CGI.escape(value.to_s)}" }.join("&")
      end
    end
  end
end

