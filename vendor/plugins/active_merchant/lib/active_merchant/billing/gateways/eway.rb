require 'rexml/document'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # First, make sure you have everything setup correctly and all of your dependencies in place with:
    # 
    #   require 'rubygems'
    #   require 'active_merchant'
    #
    # ActiveMerchant expects the amounts to be given as an Integer in cents. In this case, $10 US becomes 1000.
    #
    #   tendollar = 1000
    #
    # Next, create a credit card object using a TC approved test card.
    #
    #   creditcard = ActiveMerchant::Billing::CreditCard.new(
    #	    :number => '4111111111111111',
    #	    :month => 8,
    #	    :year => 2006,
    #	    :first_name => 'Longbob',
    #     :last_name => 'Longsen'
    #   )
    #   options = {
    #     :order_id => '1230123',
    #     :email => 'bob@testbob.com',
    #     :address => { :address1 => '47 Bobway',
    #                   :city => 'Bobville', 
    #                   :state => 'WA',
    #                   :country => 'Australia',
    #                   :zip => '2000'
    #                 }
    #     :description => 'purchased items'
    #   }
    #
    # To finish setting up, create the active_merchant object you will be using, with the eWay gateway. If you have a
    # functional eWay account, replace :login with your account info. 
    #
    #   gateway = ActiveMerchant::Billing::Base.gateway(:eway).new(:login => '87654321')
    #
    # Now we are ready to process our transaction
    #
    #   response = gateway.purchase(tendollar, creditcard, options)
    #
    # Sending a transaction to TrustCommerce with active_merchant returns a Response object, which consistently allows you to:
    #
    # 1) Check whether the transaction was successful
    #
    #   response.success?
    #
    # 2) Retrieve any message returned by eWay, either a "transaction was successful" note or an explanation of why the
    # transaction was rejected.
    #
    #   response.message
    #
    # 3) Retrieve and store the unique transaction ID returned by eWway, for use in referencing the transaction in the future.
    #
    #   response.authorization
    #
    # This should be enough to get you started with eWay and active_merchant. For further information, review the methods
    # below and the rest of active_merchant's documentation.

    class EwayGateway < Gateway 
      TEST_URL     = 'https://www.eway.com.au/gateway/xmltest/testpage.asp'
      LIVE_URL     = 'https://www.eway.com.au/gateway/xmlpayment.asp'
      
      TEST_CVN_URL = 'https://www.eway.com.au/gateway_cvn/xmltest/testpage.asp'
      LIVE_CVN_URL = 'https://www.eway.com.au/gateway_cvn/xmlpayment.asp'
      
      MESSAGES = {
        "00" => "Transaction Approved",
        "01" => "Refer to Issuer",
        "02" => "Refer to Issuer, special",	
        "03" => "No Merchant",
        "04" => "Pick Up Card",	
        "05" => "Do Not Honour",	
        "06" => "Error",
        "07" => "Pick Up Card, Special",	
        "08" => "Honour With Identification",	
        "09" => "Request In Progress",
        "10" => "Approved For Partial Amount",	
        "11" => "Approved, VIP",	
        "12" => "Invalid Transaction",	
        "13" => "Invalid Amount",
        "14" => "Invalid Card Number",	
        "15" => "No Issuer",	
        "16" => "Approved, Update Track 3",	
        "19" => "Re-enter Last Transaction",	
        "21" => "No Action Taken",	
        "22" => "Suspected Malfunction",	
        "23" => "Unacceptable Transaction Fee",	
        "25" => "Unable to Locate Record On File",	
        "30" => "Format Error",	
        "31" => "Bank Not Supported By Switch",	
        "33" => "Expired Card, Capture",	
        "34" => "Suspected Fraud, Retain Card",	
        "35" => "Card Acceptor, Contact Acquirer, Retain Card",	
        "36" => "Restricted Card, Retain Card",	
        "37" => "Contact Acquirer Security Department, Retain Card",	
        "38" => "PIN Tries Exceeded, Capture",	
        "39" => "No Credit Account",	
        "40" => "Function Not Supported",	
        "41" => "Lost Card",	
        "42" => "No Universal Account",	
        "43" => "Stolen Card",	
        "44" => "No Investment Account",	
        "51" => "Insufficient Funds",	
        "52" => "No Cheque Account",	
        "53" => "No Savings Account",	
        "54" => "Expired Card",	
        "55" => "Incorrect PIN",	
        "56" => "No Card Record",	
        "57" => "Function Not Permitted to Cardholder",	
        "58" => "Function Not Permitted to Terminal",	
        "59" => "Suspected Fraud",	
        "60" => "Acceptor Contact Acquirer",	
        "61" => "Exceeds Withdrawal Limit",	
        "62" => "Restricted Card",	
        "63" => "Security Violation",	
        "64" => "Original Amount Incorrect",	
        "66" => "Acceptor Contact Acquirer, Security",	
        "67" => "Capture Card",	
        "75" => "PIN Tries Exceeded",	
        "82" => "CVV Validation Error",	
        "90" => "Cutoff In Progress",	
        "91" => "Card Issuer Unavailable",	
        "92" => "Unable To Route Transaction",	
        "93" => "Cannot Complete, Violation Of The Law",	
        "94" => "Duplicate Transaction",	
        "96" => "System Error"
      }
      
	    self.money_format = :cents
      self.supported_countries = ['AU']
      self.supported_cardtypes = [:visa, :master, :american_express]
      self.homepage_url = 'http://www.eway.com.au/'
      self.display_name = 'eWAY'
	    
    	def initialize(options = {})
        requires!(options, :login)
        @options = options
        super
    	end

      # ewayCustomerEmail, ewayCustomerAddress, ewayCustomerPostcode
      def purchase(money, creditcard, options = {})
        requires!(options, :order_id)

        post = {}
        add_creditcard(post, creditcard)
        add_address(post, options)  
        add_customer_data(post, options)
        add_invoice_data(post, options)
        # The request fails if all of the fields aren't present
        add_optional_data(post)
    
        commit(money, post)
      end
      
      def test?
        @options[:test] || super
      end
      
      private                       
      def add_creditcard(post, creditcard)
        post[:CardNumber]  = creditcard.number
        post[:CardExpiryMonth]  = sprintf("%.2i", creditcard.month)
        post[:CardExpiryYear] = sprintf("%.4i", creditcard.year)[-2..-1]
        post[:CustomerFirstName] = creditcard.first_name
        post[:CustomerLastName]  = creditcard.last_name
        post[:CardHoldersName] = creditcard.name
              
        post[:CVN] = creditcard.verification_value if creditcard.verification_value?
      end 

      def add_address(post, options)
        if address = options[:billing_address] || options[:address]
          post[:CustomerAddress]    = [ address[:address1], address[:address2], address[:city], address[:state], address[:country] ].compact.join(', ')
          post[:CustomerPostcode]   = address[:zip]
        end
      end

      def add_customer_data(post, options)
        post[:CustomerEmail] = options[:email]
      end
      
      def add_invoice_data(post, options)
        post[:CustomerInvoiceRef] = options[:order_id]
        post[:CustomerInvoiceDescription] = options[:description]
      end

      def add_optional_data(post)
        post[:TrxnNumber] = nil
        post[:Option1] = nil
        post[:Option2] = nil
        post[:Option3] = nil     
      end

      def commit(money, parameters)       
        parameters[:TotalAmount] = amount(money)

        response = parse( ssl_post(gateway_url(parameters[:CVN], test?), post_data(parameters)) )

        Response.new(success?(response), message_from(response[:ewaytrxnerror]), response,
          :authorization => response[:ewayauthcode],
          :test => /\(Test( CVN)? Gateway\)/ === response[:ewaytrxnerror]
        )      
      end
      
      def success?(response)
        response[:ewaytrxnstatus] == "True"
      end
                                             
      # Parse eway response xml into a convinient hash
      def parse(xml)
        #  "<?xml version=\"1.0\"?>".
        #  <ewayResponse>
        #  <ewayTrxnError></ewayTrxnError>
        #  <ewayTrxnStatus>True</ewayTrxnStatus>
        #  <ewayTrxnNumber>10002</ewayTrxnNumber>
        #  <ewayTrxnOption1></ewayTrxnOption1>
        #  <ewayTrxnOption2></ewayTrxnOption2>
        #  <ewayTrxnOption3></ewayTrxnOption3>
        #  <ewayReturnAmount>10</ewayReturnAmount>
        #  <ewayAuthCode>123456</ewayAuthCode>
        #  <ewayTrxnReference>987654321</ewayTrxnReference>
        #  </ewayResponse>     

        response = {}
        xml = REXML::Document.new(xml)          
        xml.elements.each('//ewayResponse/*') do |node|

          response[node.name.downcase.to_sym] = normalize(node.text)

        end unless xml.root.nil?

        response
      end   

      def post_data(parameters = {})
        parameters[:CustomerID] = @options[:login]
        
        xml   = REXML::Document.new
        root  = xml.add_element("ewaygateway")
        
        parameters.each do |key, value|
          root.add_element("eway#{key}").text = value
        end    
        xml.to_s
      end
    
      def message_from(message)
        return '' if message.blank?
        MESSAGES[message[0,2]] || message
      end

      # Make a ruby type out of the response string
      def normalize(field)
        case field
        when "true"   then true
        when "false"  then false
        when ""       then nil
        when "null"   then nil
        else field
        end        
      end
      
      def gateway_url(cvn, test)
        if cvn
          test ? TEST_CVN_URL : LIVE_CVN_URL
        else
          test ? TEST_URL : LIVE_URL
        end
      end
      
    end
  end
end
