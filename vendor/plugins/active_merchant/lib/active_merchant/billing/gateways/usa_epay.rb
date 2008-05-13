module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
        
    class UsaEpayGateway < Gateway
    	URL = 'https://www.usaepay.com/gate.php'
      
      self.supported_cardtypes = [:visa, :master, :american_express]
      self.supported_countries = ['US']
      self.homepage_url = 'http://www.usaepay.com/'
      self.display_name = 'USA ePay'

      TRANSACTIONS = {
        :authorization => 'authonly',
        :purchase => 'sale',
        :capture => 'capture'
      }

      def initialize(options = {})
        requires!(options, :login)
        @options = options
        super
      end  
      
      def authorize(money, credit_card, options = {})
        post = {}
        
        add_amount(post, money)
        add_invoice(post, options)
        add_credit_card(post, credit_card)        
        add_address(post, credit_card, options)        
        add_customer_data(post, options)
        
        commit(:authorization, post)
      end
      
      def purchase(money, credit_card, options = {})
        post = {}
        
        add_amount(post, money)
        add_invoice(post, options)
        add_credit_card(post, credit_card)        
        add_address(post, credit_card, options)   
        add_customer_data(post, options)
             
        commit(:purchase, post)
      end                       
    
      def capture(money, authorization, options = {})
        post = {
          :refNum => authorization
        }
        
        add_amount(post, money)
        commit(:capture, post)
      end
       
      private                       
    
      def add_amount(post, money)
        post[:amount] = amount(money)
      end
      
      def expdate(credit_card)
        year  = format(credit_card.year, :two_digits)
        month = format(credit_card.month, :two_digits)

        "#{month}#{year}"
      end
      
      def add_customer_data(post, options)
        address = options[:billing_address] || options[:address] || {}
        post[:street] = address[:address1]
        post[:zip] = address[:zip]

        if options.has_key? :email
          post[:custemail] = options[:email]
          post[:custreceipt] = 'No'
        end
        
        if options.has_key? :customer
          post[:custid] = options[:customer]
        end
        
        if options.has_key? :ip
          post[:ip] = options[:ip]
        end        
      end

      def add_address(post, credit_card, options)
        billing_address = options[:billing_address] || options[:address]
        
        add_address_for_type(:billing, post, credit_card, billing_address) if billing_address
        add_address_for_type(:shipping, post, credit_card, options[:shipping_address]) if options[:shipping_address]
      end

      def add_address_for_type(type, post, credit_card, address)
        prefix = address_key_prefix(type)

        post[address_key(prefix, 'fname')] = credit_card.first_name
        post[address_key(prefix, 'lname')] = credit_card.last_name
        post[address_key(prefix, 'company')] = address[:company] unless address[:company].blank?
        post[address_key(prefix, 'street')] = address[:address1] unless address[:address1].blank?
        post[address_key(prefix, 'street2')] = address[:address2] unless address[:address2].blank?
        post[address_key(prefix, 'city')] = address[:city] unless address[:city].blank?
        post[address_key(prefix, 'state')] = address[:state] unless address[:state].blank?
        post[address_key(prefix, 'zip')] = address[:zip] unless address[:zip].blank?
        post[address_key(prefix, 'country')] = address[:country] unless address[:country].blank?
        post[address_key(prefix, 'phone')] = address[:phone] unless address[:phone].blank?
      end
      
      def address_key_prefix(type)  
        case type
        when :shipping then 'ship'
        when :billing then 'bill'
        end
      end

      def address_key(prefix, key)
        "#{prefix}#{key}".to_sym
      end
      
      def add_invoice(post, options)
        post[:invoice] = options[:order_id]
      end
      
      def add_credit_card(post, credit_card)      
        post[:card]  = credit_card.number
        post[:cvv2] = credit_card.verification_value if credit_card.verification_value?
        post[:expir]  = expdate(credit_card)
        post[:name] = credit_card.name
      end
      
      def parse(body)
        fields = {}
        for line in body.split('&')
          key, value = *line.scan( %r{^(\w+)\=(.*)$} ).flatten
          fields[key] = CGI.unescape(value)
        end

        {
          :status => fields['UMstatus'],
          :auth_code => fields['UMauthCode'],
          :ref_num => fields['UMrefNum'],
          :batch => fields['UMbatch'],
          :avs_result => fields['UMavsResult'],
          :avs_result_code => fields['UMavsResultCode'],
          :cvv2_result => fields['UMcvv2Result'],
          :cvv2_result_code => fields['UMcvv2ResultCode'],
          :vpas_result_code => fields['UMvpasResultCode'],
          :result => fields['UMresult'],
          :error => fields['UMerror'],
          :error_code => fields['UMerrorcode'],
          :acs_url => fields['UMacsurl'],
          :payload => fields['UMpayload']
        }.delete_if{|k, v| v.nil?}         
      end     

      
      def commit(action, parameters)
        response = parse( ssl_post(URL, post_data(action, parameters)) )
        
        Response.new(response[:status] == 'Approved', message_from(response), response, 
          :test => @options[:test] || test?,
          :authorization => response[:ref_num],
          :cvv_result => response[:cvv2_result_code],
          :avs_result => { 
            :street_match => response[:avs_result_code].to_s[0,1],
            :postal_match => response[:avs_result_code].to_s[1,1],
            :code => response[:avs_result_code].to_s[2,1]
          }
        )        
      end

      def message_from(response)
        if response[:status] == "Approved"
          return 'Success'
        else
          return 'Unspecified error' if response[:error].blank?
          return response[:error]
        end
      end
      
      def post_data(action, parameters = {})
        parameters[:command]  = TRANSACTIONS[action]
        parameters[:key] = @options[:login]
        parameters[:software] = 'Active Merchant'
        parameters[:testmode] = @options[:test] ? 1 : 0

        parameters.collect { |key, value| "UM#{key}=#{CGI.escape(value.to_s)}" }.join("&")
      end
    end
  end
end

