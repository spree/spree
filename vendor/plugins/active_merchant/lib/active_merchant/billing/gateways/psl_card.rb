# Author::    MoneySpyder, http://moneyspyder.co.uk

module ActiveMerchant
  module Billing
    #
    # ActiveMerchant PSL Card Gateway
    # 
    # Notes:
    #   -To be able to use the capture function, the IP address of the machine must be
    #    registered with PSL
    #   -ESALE_KEYED should only be used in situations where the cardholder perceives the 
    #    transaction to be Internet-based, such as purchasing from a web site/on-line store.  
    #    If the Internet is used purely for the transport of information from the merchant 
    #    directly to the gateway then the appropriate cardholder present or not present message 
    #    type should be used rather than the ‘E’ equivalent.
    #   -The CV2 / AVS policies are set up with the account settings when signing up for an account
    class PslCardGateway < Gateway
      self.money_format = :cents
      self.default_currency = 'GBP'
      
      self.supported_countries = ['GB']
      # Visa Credit, Visa Debit, Mastercard, Maestro, Solo, Electron,
      # American Express, Diners Club, JCB, International Maestro,
      # Style, Clydesdale Financial Services, Other
         
      self.supported_cardtypes = [ :visa, :master, :american_express, :diners_club, :jcb, :switch, :solo, :maestro ]
      self.homepage_url = 'http://www.paymentsolutionsltd.com/'
      self.display_name = 'PSL Payment Solutions'
      
      # Default ISO 3166 country code (GB)
      cattr_accessor :location
      self.location = 826
      
      # PslCard server URL - The url is the same whether testing or live - use
      # the test account when testing...
      URL = 'https://pslcard3.paymentsolutionsltd.com/secure/transact.asp?'
      
      # eCommerce sale transaction, details keyed by merchant or cardholder
      MESSAGE_TYPE = 'ESALE_KEYED' 
      
      # The type of response that we want to get from PSL, options are HTML, XML or REDIRECT
      RESPONSE_ACTION = 'HTML'
      
      # Currency Codes
      CURRENCY_CODES = {
        'AUD' => 036,
        'GBP' => 826,
        'USD' => 840
      }
      
      #The terminal used - only for swipe transactions, so hard coded to 32 for online
      EMV_TERMINAL_TYPE = 32
      
      #Different Dispatch types
      DISPATCH_LATER  = 'LATER'
      DISPATCH_NOW    = 'NOW'
      
      # Return codes
      APPROVED = '00'
      
      #Nominal amount to authorize for a 'dispatch later' type
      #The nominal amount is held straight away, when the goods are ready
      #to be dispatched, PSL is informed and the full amount is the
      #taken.
      NOMINAL_AMOUNT = 101
      
      AVS_CODE = {
        "ALL MATCH"	=> 'Y',
        "SECURITY CODE MATCH ONLY" => 'N',
        "ADDRESS MATCH ONLY" => 'Y',
        "NO DATA MATCHES"	=> 'N',
        "DATA NOT CHECKED"	=> 'R',
        "SECURITY CHECKS NOT SUPPORTED"	=> 'X'
      }
      
      CVV_CODE = {
        "ALL MATCH"	=> 'M',
        "SECURITY CODE MATCH ONLY" => 'M',
        "ADDRESS MATCH ONLY" => 'N',
        "NO DATA MATCHES"	=> 'N',
        "DATA NOT CHECKED"	=> 'P',
        "SECURITY CHECKS NOT SUPPORTED"	=> 'X'
      }
      
      # Create a new PslCardGateway
      # 
      # The gateway requires that a valid :login be passed in the options hash
      # 
      # Paramaters:
      #   -options:
      #     :login -    the PslCard account login (required)
      def initialize(options = {})
        requires!(options, :login)
              
        @options = options
        super
      end

      # Purchase the item straight away
      # 
      # Parameters:
      #   -money: Money object for the total to be charged
      #   -authorization: the PSL cross reference from the previous authorization
      #   -options:
      #
      # Returns:
      #   -ActiveRecord::Billing::Response object
      #   
      def purchase(money, credit_card, options = {})
        post = {}
        
        add_amount(post, money, DISPATCH_NOW, options)
        add_credit_card(post, credit_card)
        add_address(post, options)
        add_invoice(post, options)
        add_purchase_details(post)
        
        commit(post)
      end
      
      # Authorize the transaction
      # 
      # Reserves the funds on the customer's credit card, but does not 
      # charge the card.
      #
      # This implementation does not authorize the full amount, rather it checks that the full amount
      # is available and only 'reserves' the nominal amount (currently a pound and a penny)
      # 
      # Parameters:
      #   -money: Money object for the total to be charged
      #   -authorization: the PSL cross reference from the previous authorization
      #   -options:
      #
      # Returns:
      #   -ActiveRecord::Billing::Response object
      #   
      def authorize(money, credit_card, options = {})
        post = {}
      
        add_amount(post, money, DISPATCH_LATER, options)
        add_credit_card(post, credit_card)
        add_address(post, options)
        add_invoice(post, options)
        add_purchase_details(post)
              
        commit(post)
      end
      
      # Post an authorization. 
      #
      # Captures the funds from an authorized transaction. 
      # 
      # Parameters:
      #   -money: Money object for the total to be charged
      #   -authorization: The PSL Cross Reference
      #   -options:
      #
      # Returns:
      #   -ActiveRecord::Billing::Response object
      #
      def capture(money, authorization, options = {})
        post = {}
      
        add_amount(post, money, DISPATCH_NOW, options)
        add_reference(post, authorization)
        add_purchase_details(post)

        commit(post)
      end

      private
    
      def add_credit_card(post, credit_card)
        post[:QAName] = credit_card.name
        post[:CardNumber] = credit_card.number
        post[:EMVTerminalType] = EMV_TERMINAL_TYPE
        post[:ExpMonth] = credit_card.month
        post[:ExpYear] = credit_card.year
        
        if requires_start_date_or_issue_number?(credit_card)        
          post[:IssueNumber] = credit_card.issue_number unless credit_card.issue_number.blank?
          post[:StartMonth] = credit_card.start_month unless credit_card.start_month.blank?
          post[:StartYear] = credit_card.start_year unless credit_card.start_year.blank?
        end
        
        # CV2 check
        post[:AVSCV2Check] = credit_card.verification_value? ? 'YES' : 'NO'
        post[:CV2] = credit_card.verification_value if credit_card.verification_value?
      end
      
      def add_address(post, options)
        address = options[:billing_address] || options[:address]
        return if address.nil?
      
        post[:QAAddress] = [:address1, :address2, :city, :state].collect{|a| address[a]}.reject{|a| a.blank?}.join(' ')
        post[:QAPostcode] = address[:zip]
      end
        
      def add_invoice(post, options)
        post[:MerchantName] = options[:merchant] || 'Merchant Name' # May use this as the order_id field
        post[:OrderID] = options[:order_id] unless options[:order_id].blank?
      end
    
      def add_reference(post, authorization)
        post[:CrossReference] = authorization
      end
      
      def add_amount(post, money, dispatch_type, options)
        post[:CurrencyCode] = currency_code(options[:currency] || currency(money))
        
        if dispatch_type == DISPATCH_LATER
          post[:amount] = amount(NOMINAL_AMOUNT)
          post[:DispatchLaterAmount] = amount(money)
        else
          post[:amount] = amount(money)
        end
        
        post[:Dispatch] = dispatch_type
      end
      
      def add_purchase_details(post)
        post[:EchoAmount] = 'YES'
        post[:SCBI] = 'YES'                   # Return information about the transaction
        post[:MessageType] = MESSAGE_TYPE
      end
    
      # Get the currency code for the passed money object
      # 
      # The money class stores the currency as an ISO 4217:2001 Alphanumeric,
      # however PSL requires the ISO 4217:2001 Numeric code.
      # 
      # Parameters:
      #   -money: Money object with the amount and currency
      #   
      # Returns:
      #   -the ISO 4217:2001 Numberic currency code
      #   
      def currency_code(currency)
        CURRENCY_CODES[currency]
      end
      
      # Parse the PSL response and create a Response object
      #
      # Parameters:
      #   -body:  The response string returned from PSL, Formatted:
      #           Key=value&key=value...
      # 
      # Returns:
      #   -a hash with all of the values returned in the PSL response
      #
      def parse(body)

        fields = {}
        for line in body.split('&')
          key, value = *line.scan( %r{^(\w+)\=(.*)$} ).flatten
          fields[key] = CGI.unescape(value)
        end
        fields.symbolize_keys
      end
      
      # Send the passed data to PSL for processing
      #
      # Parameters:
      #   -request: The data that is to be sent to PSL
      #
      # Returns:
      #   - ActiveMerchant::Billing::Response object
      #
      def commit(request)
        response = parse( ssl_post(URL, post_data(request)) )
        
        Response.new(response[:ResponseCode] == APPROVED, response[:Message], response, 
          :test => test?, 
          :authorization => response[:CrossReference],
          :cvv_result => CVV_CODE[response[:AVSCV2Check]],
          :avs_result => { :code => AVS_CODE[response[:AVSCV2Check]] }
        )
      end
      
      # Put the passed data into a format that can be submitted to PSL
      # Key=Value&Key=Value...
      #
      # Any ampersands and equal signs are removed from the data being posted
      # as PSL puts them back into the response string which then cannot be parsed. 
      # This is after escaping before sending the request to PSL - this is a work
      # around for the time being
      # 
      # Parameters:
      #   -post: Hash of all the data to be sent
      #
      # Returns:
      #   -String: the data to be sent
      #
      def post_data(post)
        post[:CountryCode] = self.location
        post[:MerchantID] = @options[:login]
        post[:ValidityID] = @options[:password]
        post[:ResponseAction] = RESPONSE_ACTION
        
        post.collect { |key, value|
          "#{key}=#{CGI.escape(value.to_s.tr('&=', ' '))}"
        }.join("&")
      end
    end
  end
end
