module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class InstapayGateway < Gateway
      GATEWAY_URL = 'https://trans.instapaygateway.com/cgi-bin/process.cgi'

      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = ['US']
      self.money_format = :dollars
      self.default_currency = 'USD'
      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      # The homepage URL of the gateway
      self.homepage_url = 'http://www.instapayllc.com'

      # The name of the gateway
      self.display_name = 'InstaPay'
      
      SUCCESS         = "Accepted"
      SUCCESS_MESSAGE = "The transaction has been approved"

      def initialize(options = {})
        requires!(options, :login)
        @options = options
        super
      end

      def authorize(money, creditcard, options = {})
        post = {}
        post[:authonly] = 1
        add_amount(post, money)
        add_invoice(post, options)
        add_creditcard(post, creditcard)
        add_address(post, options)
        add_customer_data(post, options)

        commit('ns_quicksale_cc', post)
      end

      def purchase(money, creditcard, options = {})
        post = {}
        add_amount(post, money)
        add_invoice(post, options)
        add_creditcard(post, creditcard)
        add_address(post, options)
        add_customer_data(post, options)

        commit('ns_quicksale_cc', post)
      end
      
      def capture(money, authorization, options = {})
        post = {}
        add_amount(post, money)
        add_reference(post, authorization)        
        commit('ns_quicksale_cc', post)
      end

      private
      
      def add_amount(post, money)
        post[:amount] = amount(money)
      end
      
      def add_reference(post, reference)
        post[:postonly] = reference
      end
        
      def add_customer_data(post, options)
        post[:ci_email]       = options[:email]
        post["ci_IP Address"] = options[:ip]
      end

      def add_address(post, options)
        if address = options[:billing_address] || options[:address]
          post[:ci_billaddr1]   = address[:address1]
          post[:ci_billaddr2]   = address[:address2]
          post[:ci_billcity]    = address[:city]
          post[:ci_billstate]   = address[:state]
          post[:ci_billzip]     = address[:zip]
          post[:ci_billcountry] = address[:country]
          post[:ci_phone]       = address[:phone]
        end

        if address = options[:shipping_address]
          post[:ci_shipaddr1]   = address[:address1]
          post[:ci_shipaddr2]   = address[:address2]
          post[:ci_shipcity]    = address[:city]
          post[:ci_shipstate]   = address[:state]
          post[:ci_shipzip]     = address[:zip]
          post[:ci_shipcountry] = address[:country]  
        end
      end

      def add_invoice(post, options)
        post[:merchantordernumber] = options[:order_id]
        post[:ci_memo]             = options[:description]
        post[:pocustomerrefid]     = options[:invoice]
      end

      def add_creditcard(post, creditcard)
        post[:ccnum]   = creditcard.number
        post[:expmon]  = format(creditcard.month, :two_digits)
        post[:cvv2]    = creditcard.verification_value if creditcard.verification_value?
        post[:expyear] = creditcard.year
        post[:ccname]  = creditcard.name
      end

      def parse(body)
        results = {}
        fields = body.split("\r\n")
        
        response = fields[1].split('=')        
        response_data = response[1].split(':')
        
        if response[0] == SUCCESS
          results[:success] = true
          results[:message] = SUCCESS_MESSAGE
          results[:transaction_type] = response_data[0]
          results[:authorization_code] = response_data[1]
          results[:reference_number] = response_data[2]
          results[:batch_number] = response_data[3]
          results[:transaction_id] = response_data[4]
          results[:avs_result] = response_data[5]
          results[:authorize_net] = response_data[6]
          results[:cvv_result] = response_data[7]
        else
          results[:success] = false
          results[:result] = response_data[0]
          results[:response_code] = response_data[1]
          results[:message] = response_data[2]
        end

        fields[1..-1].each do |pair|
          key, value = pair.split('=')
          results[key] = value
        end
        results
      end

      def commit(action, parameters)
        data = ssl_post GATEWAY_URL , post_data(action, parameters)
        response = parse(data)

        Response.new(response[:success] , response[:message], response,
          :authorization => response[:transaction_id],
          :avs_result => { :code => response[:avs_result] },
          :cvv_result => response[:cvv_result]
        )
      end

      def post_data(action, parameters = {})
        post = {}
        post[:acctid] = @options[:login]
        if(@options[:password])
          post[:merchantpin] = @options[:password]
        end
        post[:action] = action
        request = post.merge(parameters).collect { |key, value| "#{key}=#{CGI.escape(value.to_s)}" }.join("&")
        request
      end
    end
  end
end

