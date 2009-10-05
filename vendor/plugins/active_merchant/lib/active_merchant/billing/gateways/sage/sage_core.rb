module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module SageCore #:nodoc:
      def self.included(base)
        base.cattr_accessor :url
        base.cattr_accessor :source
        base.supported_countries = ['US', 'CA']
        base.homepage_url = 'http://www.sagepayments.com'
        base.display_name = 'Sage Payment Solutions'
      end
      
      # Transactions types:
      # <tt>01</tt> - Sale
      # <tt>02</tt> - AuthOnly 
      # <tt>03</tt> - Force/PriorAuthSale 
      # <tt>04</tt> - Void 
      # <tt>06</tt> - Credit 
      # <tt>11</tt> - PriorAuthSale by Reference*
      TRANSACTIONS = {
        :purchase           => '01',
        :authorization      => '02',
        :capture            => '11',
        :void               => '04',
        :credit             => '06'
      }
      
      def initialize(options = {})
        requires!(options, :login, :password)
        @options = options
        super
      end
      
      private
      def add_invoice(post, options)
        post[:T_ordernum] = options[:order_id].slice(0, 20)
        post[:T_tax] = amount(options[:tax]) unless options[:tax].blank?
        post[:T_shipping] = amount(options[:shipping]) unless options[:shipping].blank?
      end
      
      def add_reference(post, reference)
        ref, source = reference.to_s.split(";")
        post[:T_reference] = ref
      end
      
      def add_amount(post, money)
        post[:T_amt] = amount(money)
      end
      
      def add_customer_data(post, options)
        post[:T_customer_number] = options[:customer]
      end

      def add_addresses(post, options)
        billing_address   = options[:billing_address] || options[:address] || {}
        
        post[:C_address]    = billing_address[:address1]
        post[:C_city]       = billing_address[:city]
        post[:C_state]      = billing_address[:state]
        post[:C_zip]        = billing_address[:zip]
        post[:C_country]    = billing_address[:country] 
        post[:C_telephone]  = billing_address[:phone]
        post[:C_fax]        = billing_address[:fax]
        post[:C_email]      = options[:email]
        
        if shipping_address = options[:shipping_address]
          post[:C_ship_name]    = shipping_address[:name]
          post[:C_ship_address] = shipping_address[:address1]
          post[:C_ship_city]    = shipping_address[:city]
          post[:C_ship_state]   = shipping_address[:state]
          post[:C_ship_zip]     = shipping_address[:zip] 
          post[:C_ship_country] = shipping_address[:country]
        end
      end
      
      def add_transaction_data(post, money, options)
        add_amount(post, money)
        add_invoice(post, options)
        add_addresses(post, options)        
        add_customer_data(post, options)
      end
      
      def commit(action, params)
        response = parse(ssl_post(url, post_data(action, params)))
        
        Response.new(success?(response), response[:message], response, 
          :test => test?, 
          :authorization => authorization_from(response),
          :avs_result => { :code => response[:avs_result] },
          :cvv_result => response[:cvv_result]
        )
      end
      
      def authorization_from(response)
        "#{response[:reference]};#{source}"
      end
            
      def success?(response)
        response[:success] == 'A'
      end

      def post_data(action, params = {})
        params[:M_id]  = @options[:login]
        params[:M_key] = @options[:password]
        params[:T_code] = TRANSACTIONS[action]
        
        params.collect { |key, value| "#{key}=#{CGI.escape(value.to_s)}" }.join("&")
      end
    end
  end
end