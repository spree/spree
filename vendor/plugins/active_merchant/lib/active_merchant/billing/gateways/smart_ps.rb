require File.join(File.dirname(__FILE__), '..', 'check.rb')

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class SmartPs < Gateway #:nodoc:
      
      ##
      # This is the base gateway for processors who use the smartPS processing system

      def initialize(options = {})
        requires!(options, :login, :password)
        @options = options
        super
      end  
      
      # Pass :store => true in the options to store the 
      # payment info at the gateway and get a generated 
      # customer_vault_id in the response.  
      # Pass :store => some_number_or_string to specify the
      # customer_vault_id the gateway should use (make sure it's
      # unique).
      def authorize(money, creditcard, options = {})
        post = {}
        add_invoice(post, options)
        add_payment_source(post, creditcard,options)        
        add_address(post, options[:billing_address]||options[:address])
        add_address(post, options[:shipping_address],"shipping")
        add_customer_data(post, options)
        
        commit('auth', money, post)
      end
      
      def purchase(money, payment_source, options = {})
        post = {}
        add_invoice(post, options)
        add_payment_source(post, payment_source, options)        
        add_address(post, options)   
        add_address(post, options[:shipping_address],"shipping")        
        add_customer_data(post, options)
             
        commit('sale', money, post)
      end                       
    
      def capture(money, authorization, options = {})
        post ={}
        post[:transactionid] = authorization
        commit('capture', money, post)
      end
      
      def void(authorization, options = {})
        post ={}
        post[:transactionid] = authorization
        commit('void', nil, post)
      end
      
      def credit(money, payment_source, options = {})
        post = {}
        add_invoice(post, options)
        add_payment_source(post, payment_source, options)        
        add_address(post, options)
        add_customer_data(post, options)
        add_sku(post,options)
        
        commit('credit', money, post)
      end
      
      def refund(auth, options = {})
        post = {}
        add_transaction(post, auth)
        commit('refund', options.delete(:amount), post)
      end
      
      
      # Update the values (such as CC expiration) stored at
      # the gateway.  The CC number must be supplied in the
      # CreditCard object.
      def update(vault_id, creditcard, options = {})
        post = {}
        post[:customer_vault] = "update_customer"
        add_customer_vault_id(post, vault_id)
        add_creditcard(post, creditcard, options)        
        add_address(post, options)   
        add_customer_data(post, options)
             
        commit(nil, nil, post)
      end
      
      # Amend an existing transaction
      def amend(auth, options = {})
        post = {}
        add_invoice(post, options)
        add_transaction(post, auth)
        commit('update', nil, post)
      end
      
    
      def delete(vault_id)
        post = {}
        post[:customer_vault] = "delete_customer"
        add_customer_vault_id(post, vault_id)         
        commit(nil, nil, post)
      end
    
      # To match the other stored-value gateways, like TrustCommerce,
      # store and unstore need to be defined
      def store(payment_source, options = {})
        post = {}
        billing_id = options.delete(:billing_id).to_s || true
        add_payment_source(post, payment_source, :store => billing_id)
        add_address(post, options[:billing_address] || options[:address])
        add_customer_data(post, options)
        commit(nil, nil, post)
      end
      
      alias_method :unstore, :delete

      private                             
      def add_customer_data(post, options)
        if options.has_key? :email
          post[:email] = options[:email]
        end

        if options.has_key? :ip
          post[:ipaddress] = options[:ip]
        end        
      end

      def add_address(post, address,prefix="")     
        prefix +="_" unless prefix.blank? 
        unless address.blank? or address.values.blank?
          post[prefix+"address1"]    = address[:address1].to_s
          post[prefix+"address2"]    = address[:address2].to_s unless address[:address2].blank?
          post[prefix+"company"]    = address[:company].to_s
          post[prefix+"phone"]      = address[:phone].to_s
          post[prefix+"zip"]        = address[:zip].to_s       
          post[prefix+"city"]       = address[:city].to_s
          post[prefix+"country"]    = address[:country].to_s
          post[prefix+"state"]      = address[:state].blank?  ? 'n/a' : address[:state]
        end         
      end

      def add_invoice(post, options)
        post[:orderid] = options[:order_id].to_s.gsub(/[^\w.]/, '')
      end
      
      def add_payment_source(params, source, options={})
        case determine_funding_source(source)
        when :vault       then add_customer_vault_id(params, source)
        when :credit_card then add_creditcard(params, source, options)
        when :check       then add_check(params, source, options)
        end
      end
      
      def add_customer_vault_id(params, vault_id)
        params[:customer_vault_id] = vault_id
      end
      
      def add_creditcard(post, creditcard, options)
        if options[:store]  
          post[:customer_vault] = "add_customer"
          post[:customer_vault_id] = options[:store] unless options[:store] == true
        end
        post[:ccnumber]  = creditcard.number
        post[:cvv] = creditcard.verification_value if creditcard.verification_value?
        post[:ccexp]  = expdate(creditcard)
        post[:firstname] = creditcard.first_name
        post[:lastname]  = creditcard.last_name   
      end
      
      def add_check(post, check, options)
        if options[:store]  
          post[:customer_vault] = "add_customer"
          post[:customer_vault_id] = options[:store] unless options[:store] == true
        end
        
        post[:payment] = 'check' # Set transaction to ACH
        post[:checkname] = check.name # The name on the customer's Checking Account
        post[:checkaba] = check.routing_number # The customer's bank routing number
        post[:checkaccount] = check.account_number # The customer's account number
        post[:account_holder_type] = check.account_holder_type # The customer's type of ACH account
        post[:account_type] = check.account_type # The customer's type of ACH account
      end
      
      def add_sku(post,options)
        post["product_sku_#"] = options[:sku] || options["product_sku_#"]
      end
      
      def add_transaction(post, auth)
        post[:transactionid] = auth
      end
      
      def parse(body)
        results = {}
        body.split(/&/).each do |pair|
          key,val = pair.split(/=/)
          results[key] = val
        end
        
        results
      end     
      
      def commit(action, money, parameters)
        parameters[:amount]  = amount(money) if money
        response = parse( ssl_post(api_url, post_data(action,parameters)) )
        Response.new(response["response"] == "1", message_from(response), response, 
          :authorization => response["transactionid"],
          :test => test?,
          :cvv_result => response["cvvresponse"],
          :avs_result => { :code => response["avsresponse"] }
        )
        
      end
      
      def expdate(creditcard)
        year  = sprintf("%.04i", creditcard.year.to_i)
        month = sprintf("%.02i", creditcard.month.to_i)

        "#{month}#{year[-2..-1]}"
      end
      

      def message_from(response)
        case response["responsetext"]
        when "SUCCESS", "Approved", nil # This is dubious, but responses from UPDATE are nil.
          "This transaction has been approved"
        when "DECLINE"
          "This transaction has been declined"
        else
          response["responsetext"]
        end
      end
      
      def post_data(action, parameters = {})
        post = {}
        post[:username]      = @options[:login]
        post[:password]   = @options[:password]
        post[:type]       = action if action

        request = post.merge(parameters).map {|key,value| "#{key}=#{CGI.escape(value.to_s)}"}.join("&")
        request        
      end
      
      def determine_funding_source(source)
        case 
        when source.is_a?(String) then :vault
        when CreditCard.card_companies.keys.include?(card_brand(source)) then :credit_card
        when card_brand(source) == 'check' then :check
        else raise ArgumentError, "Unsupported funding source provided"
        end
      end
    end    
  end
end

