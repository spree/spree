require 'rexml/document'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    
    # In NZ DPS supports ANZ, Westpac, National Bank, ASB and BNZ. 
    # In Australia DPS supports ANZ, NAB, Westpac, CBA, St George and Bank of South Australia. 
    # The Maybank in Malaysia is supported and the Citibank for Singapore.
    class PaymentExpressGateway < Gateway
      self.default_currency = 'NZD'
      # PS supports all major credit cards; Visa, Mastercard, Amex, Diners, BankCard & JCB. 
      # Various white label cards can be accepted as well; Farmers, AirNZCard and Elders etc. 
      # Please note that not all acquirers and Eftpos networks can support some of these card types.
      # VISA, Mastercard, Diners Club and Farmers cards are supported
      #
      # However, regular accounts with DPS only support VISA and Mastercard
      self.supported_cardtypes = [ :visa, :master, :american_express, :diners_club, :jcb ]
      
      self.supported_countries = [ 'AU', 'MY', 'NZ', 'SG', 'ZA', 'GB', 'US' ]
      
      self.homepage_url = 'http://www.paymentexpress.com/'
      self.display_name = 'PaymentExpress'
      
      URL = 'https://www.paymentexpress.com/pxpost.aspx'
      
      APPROVED = '1'
      
      TRANSACTIONS = {
        :purchase       => 'Purchase',
        :credit         => 'Refund',
        :authorization  => 'Auth',
        :capture        => 'Complete',
        :validate       => 'Validate'
      }
      
      # We require the DPS gateway username and password when the object is created.
      def initialize(options = {})
        # A DPS username and password must exist 
        requires!(options, :login, :password)
        # Make the options an instance variable
        @options = options
        super
      end
      
      # Funds are transferred immediately.
      def purchase(money, payment_source, options = {})
        request = build_purchase_or_authorization_request(money, payment_source, options)
        commit(:purchase, request)      
      end
      
      # NOTE: Perhaps in options we allow a transaction note to be inserted
      # Verifies that funds are available for the requested card and amount and reserves the specified amount.
      # See: http://www.paymentexpress.com/technical_resources/ecommerce_nonhosted/pxpost.html#Authcomplete
      def authorize(money, payment_source, options = {})
        request = build_purchase_or_authorization_request(money, payment_source, options)
        commit(:authorization, request)
      end
      
      # Transfer pre-authorized funds immediately
      # See: http://www.paymentexpress.com/technical_resources/ecommerce_nonhosted/pxpost.html#Authcomplete
      def capture(money, identification, options = {})
        request = build_capture_or_credit_request(money, identification, options)                                            
        commit(:capture, request)
      end
      
      # Refund funds to the card holder
      def credit(money, identification, options = {})
        requires!(options, :description)
        
        request = build_capture_or_credit_request(money, identification, options)                                            
        commit(:credit, request)
      end
      
      # token based billing
      
      # initiates a "Validate" transcation to store card data on payment express servers
      # returns a "token" that can be used to rebill this card
      # see: http://www.paymentexpress.com/technical_resources/ecommerce_nonhosted/pxpost.html#Tokenbilling
      # PaymentExpress does not support unstoring a stored card.
      def store(credit_card, options = {})
        request  = build_token_request(credit_card, options)
        commit(:validate, request)
      end
      
      private
      
      def build_purchase_or_authorization_request(money, payment_source, options)
        result = new_transaction      

        if payment_source.is_a?(String)
          add_billing_token(result, payment_source)
        else
          add_credit_card(result, payment_source)
        end
        
        add_amount(result, money, options)
        add_invoice(result, options)
        add_address_verification_data(result, options)
        result
      end
      
      def build_capture_or_credit_request(money, identification, options)
        result = new_transaction
      
        add_amount(result, money, options)
        add_invoice(result, options)
        add_reference(result, identification)
        result
      end
      
      def build_token_request(credit_card, options)
        result = new_transaction
        add_credit_card(result, credit_card)
        add_amount(result, 100, options) #need to make an auth request for $1
        add_token_request(result, options)
        result
      end
      
      def add_credentials(xml)
        xml.add_element("PostUsername").text = @options[:login]
        xml.add_element("PostPassword").text = @options[:password]
      end
      
      def add_reference(xml, identification)
        xml.add_element("DpsTxnRef").text = identification
      end
      
      def add_credit_card(xml, credit_card)
        xml.add_element("CardHolderName").text = credit_card.name
        xml.add_element("CardNumber").text = credit_card.number
        xml.add_element("DateExpiry").text = format_date(credit_card.month, credit_card.year)
        
        if credit_card.verification_value?
          xml.add_element("Cvc2").text = credit_card.verification_value
        end
        
        if requires_start_date_or_issue_number?(credit_card)
          xml.add_element("DateStart").text = format_date(credit_card.start_month, credit_card.start_year) unless credit_card.start_month.blank? || credit_card.start_year.blank?
          xml.add_element("IssueNumber").text = credit_card.issue_number unless credit_card.issue_number.blank?
        end
      end
      
      def add_billing_token(xml, token) 
        xml.add_element("DpsBillingId").text = token
      end
      
      def add_token_request(xml, options)
        xml.add_element("BillingId").text = options[:billing_id] if options[:billing_id]
        xml.add_element("EnableAddBillCard").text = 1
      end
      
      def add_amount(xml, money, options)
        xml.add_element("Amount").text = amount(money)
        xml.add_element("InputCurrency").text = options[:currency] || currency(money)
      end
      
      def add_transaction_type(xml, action)
        xml.add_element("TxnType").text = TRANSACTIONS[action]
      end
      
      def add_invoice(xml, options)
        xml.add_element("TxnId").text = options[:order_id].to_s.slice(0, 16) unless options[:order_id].blank?
        xml.add_element("MerchantReference").text = options[:description] unless options[:description].blank?
      end
      
      def add_address_verification_data(xml, options)
        address = options[:billing_address] || options[:address]
        return if address.nil?
        
        xml.add_element("EnableAvsData").text = 1
        xml.add_element("AvsAction").text = 1
        
        xml.add_element("AvsStreetAddress").text = address[:address1]
        xml.add_element("AvsPostCode").text = address[:zip]
      end
      
      def new_transaction
        REXML::Document.new.add_element("Txn")
      end

      # Take in the request and post it to DPS
      def commit(action, request)
        add_credentials(request)
        add_transaction_type(request, action)
        
        # Parse the XML response
        response = parse( ssl_post(URL, request.to_s) )
        
        # Return a response
        PaymentExpressResponse.new(response[:success] == APPROVED, response[:response_text], response,
          :test => response[:test_mode] == '1',
          :authorization => response[:dps_txn_ref]
        )
      end

      # Response XML documentation: http://www.paymentexpress.com/technical_resources/ecommerce_nonhosted/pxpost.html#XMLTxnOutput
      def parse(xml_string)
        response = {}

        xml = REXML::Document.new(xml_string)          

        # Gather all root elements such as HelpText
        xml.elements.each('Txn/*') do |element|
          response[element.name.underscore.to_sym] = element.text unless element.name == 'Transaction'
        end

        # Gather all transaction elements and prefix with "account_"
        # So we could access the MerchantResponseText by going
        # response[account_merchant_response_text]
        xml.elements.each('Txn/Transaction/*') do |element|
          response[element.name.underscore.to_sym] = element.text
        end
        
        response
      end
      
      def format_date(month, year)
        "#{format(month, :two_digits)}#{format(year, :two_digits)}"
      end
    end
    
    class PaymentExpressResponse < Response
      # add a method to response so we can easily get the token
      # for Validate transactions
      def token
        @params["billing_id"] || @params["dps_billing_id"]
      end
    end
  end
end